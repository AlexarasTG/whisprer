import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published private(set) var permissions: PermissionSnapshot
    @Published private(set) var lastTranscript = ""

    private let permissionManager = PermissionManager()
    private let recorder = AudioRecorder()
    private let transcriptionEngine: TranscriptionEngine = WhisperCLIEngine()
    private let transcriptPostProcessor = TranscriptPostProcessor()
    private let textInsertionService = TextInsertionService()
    private let hotkeyManager = RightOptionHotkeyManager()
    private let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "AppCoordinator")
    private var cancellables = Set<AnyCancellable>()
    private var isRequestingPermissions = false
    private var accessibilityRefreshTask: Task<Void, Never>?

    init() {
        permissions = permissionManager.snapshot()
        logger.debug("Initialized with permissions: \(Self.describe(permissions: self.permissions), privacy: .public)")
        hotkeyManager.onPressed = { [weak self] in
            self?.handleHotkeyPressed()
        }
        hotkeyManager.onReleased = { [weak self] in
            self?.handleHotkeyReleased()
        }
        hotkeyManager.startMonitoring()
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleApplicationDidBecomeActive()
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleApplicationDidFinishLaunching()
                }
            }
            .store(in: &cancellables)
    }

    func requestPermissions() {
        logger.debug("Manual permission request triggered")
        Task {
            await requestMissingPermissions()

            if !self.permissions.readyForEndToEndFlow {
                self.setState(.error(self.permissionGuidanceMessage()))
            }
        }
    }

    func clearError() {
        if case .error = state {
            setState(.idle)
        }
    }

    func refreshPermissions() {
        permissions = permissionManager.snapshot()
        logger.debug("Permission snapshot refreshed: \(Self.describe(permissions: self.permissions), privacy: .public)")
        handlePermissionStateChange()
    }

    func handleMenuBarOpened() {
        logger.debug("Menu bar opened; refreshing permissions")
        refreshPermissions()

        if !permissions.accessibilityGranted {
            scheduleAccessibilityRefreshRetriesIfNeeded(reason: "menu open")
        }
    }

    private func handleApplicationDidFinishLaunching() async {
        refreshPermissions()

        guard !permissions.readyForEndToEndFlow else {
            return
        }

        await requestMissingPermissions()
        scheduleAccessibilityRefreshRetriesIfNeeded(reason: "launch")
    }

    private func handleHotkeyPressed() {
        logger.debug("Hotkey pressed while state=\(Self.describe(state: self.state), privacy: .public)")
        Task {
            await startRecordingIfPossible()
        }
    }

    private func handleHotkeyReleased() {
        logger.debug("Hotkey released while state=\(Self.describe(state: self.state), privacy: .public)")
        Task {
            await stopRecordingIfNeeded()
        }
    }

    private func startRecordingIfPossible() async {
        logger.debug("Starting recording attempt")
        refreshPermissions()

        if case .recording = state {
            logger.debug("Ignoring hotkey press because recording is already active")
            return
        }

        switch state {
        case .transcribing, .inserting:
            logger.debug("Ignoring hotkey press because state=\(Self.describe(state: self.state), privacy: .public)")
            return
        case .idle, .error:
            break
        case .recording:
            return
        }

        switch preparePermissionsForRecording() {
        case .ready:
            logger.debug("Permissions ready for recording")
            break
        case let .blocked(message):
            logger.debug("Recording blocked by permissions: \(message, privacy: .public)")
            await requestMissingPermissions()
            setState(.error(postPermissionAttemptMessage(fallback: message)))
            return
        }

        do {
            try recorder.startRecording()
            setState(.recording)
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription, privacy: .public)")
            setState(.error(error.localizedDescription))
        }
    }

    private func preparePermissionsForRecording() -> PermissionPreparationResult {
        logger.debug(
            "Preparing permissions. Current snapshot: \(Self.describe(permissions: self.permissions), privacy: .public)"
        )

        refreshPermissions()

        guard permissions.readyForEndToEndFlow else {
            logger.debug("Permissions incomplete for recording: \(Self.describe(permissions: self.permissions), privacy: .public)")
            return .blocked(permissionGuidanceMessage())
        }

        return .ready
    }

    private func requestMissingPermissions() async {
        guard !isRequestingPermissions else {
            logger.debug("Ignoring permission request because another permission flow is already active")
            return
        }

        isRequestingPermissions = true
        defer { isRequestingPermissions = false }

        refreshPermissions()

        if !permissions.microphoneGranted {
            logger.debug("Requesting microphone permission")
            _ = await permissionManager.requestMicrophoneAccess()
            refreshPermissions()
        }

        guard permissions.microphoneGranted else {
            logger.debug("Microphone permission is still missing after request")
            return
        }

        if !permissions.accessibilityGranted {
            logger.debug("Requesting accessibility permission")
            permissionManager.promptForAccessibilityAccess()
            refreshPermissions()
            scheduleAccessibilityRefreshRetriesIfNeeded(reason: "accessibility prompt")
        }
    }

    private func postPermissionAttemptMessage(fallback: String) -> String {
        if permissions.readyForEndToEndFlow {
            return "Permissions updated. Press Right Option again to start dictation."
        }

        return fallback
    }

    private func permissionGuidanceMessage() -> String {
        switch (permissions.accessibilityGranted, permissions.microphoneGranted) {
        case (false, false):
            return "Grant accessibility and microphone permissions, then press Right Option again."
        case (false, true):
            return "Grant accessibility permission, then press Right Option again."
        case (true, false):
            return "Grant microphone permission, then press Right Option again."
        case (true, true):
            return "Permissions updated. Press Right Option again to start dictation."
        }
    }

    private func stopRecordingIfNeeded() async {
        guard case .recording = state else {
            logger.debug("Ignoring hotkey release because no recording is active")
            return
        }

        logger.debug("Stopping recording and starting transcription")
        setState(.transcribing)

        do {
            let audioFileURL = try await recorder.stopRecording()
            defer { deleteTemporaryRecording(at: audioFileURL) }
            logger.debug("Recorder returned audio file: \(audioFileURL.path, privacy: .public)")
            logger.debug("Invoking transcription engine")
            let transcript = try await transcriptionEngine.transcribe(audioFileURL: audioFileURL)
            logger.debug("Raw transcript: \(transcript, privacy: .public)")
            let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            let processedTranscript = transcriptPostProcessor
                .process(trimmedTranscript)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            logger.debug("Processed transcript: \(processedTranscript, privacy: .public)")
            logger.debug("Transcription completed. Character count=\(processedTranscript.count)")

            guard !processedTranscript.isEmpty else {
                logger.error("Transcript was empty after trimming")
                setState(.error("No speech was detected in the recording."))
                return
            }

            if processedTranscript != trimmedTranscript {
                logger.debug("Post-processing transformed the transcript")
            }

            lastTranscript = processedTranscript
            logger.debug("Starting text insertion")
            setState(.inserting)
            try await textInsertionService.insert(text: processedTranscript)
            logger.debug("Text insertion completed")
            setState(.idle)
        } catch {
            logger.error("End-to-end flow failed: \(error.localizedDescription, privacy: .public)")
            setState(.error(error.localizedDescription))
        }
    }

    private func deleteTemporaryRecording(at audioFileURL: URL) {
        do {
            try FileManager.default.removeItem(at: audioFileURL)
            logger.debug("Deleted temporary recording at \(audioFileURL.path, privacy: .public)")
        } catch {
            logger.error("Failed to delete temporary recording at \(audioFileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func setState(_ newState: AppState) {
        logger.debug("State transition: \(Self.describe(state: self.state), privacy: .public) -> \(Self.describe(state: newState), privacy: .public)")
        state = newState
    }

    private func handleApplicationDidBecomeActive() {
        logger.debug("Application became active; refreshing permissions")
        refreshPermissions()

        if !permissions.accessibilityGranted {
            scheduleAccessibilityRefreshRetriesIfNeeded(reason: "app activation")
        }
    }

    private func handlePermissionStateChange() {
        if permissions.readyForEndToEndFlow {
            accessibilityRefreshTask?.cancel()
            accessibilityRefreshTask = nil

            if isPermissionError(state) {
                setState(.idle)
            }
        }
    }

    private func scheduleAccessibilityRefreshRetriesIfNeeded(reason: String) {
        guard !permissions.accessibilityGranted else {
            accessibilityRefreshTask?.cancel()
            accessibilityRefreshTask = nil
            return
        }

        accessibilityRefreshTask?.cancel()
        accessibilityRefreshTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for attempt in 1...10 {
                try? await Task.sleep(nanoseconds: 500_000_000)

                if Task.isCancelled {
                    return
                }

                self.logger.debug("Retrying accessibility refresh (\(attempt)/10) after \(reason, privacy: .public)")
                self.refreshPermissions()

                if self.permissions.accessibilityGranted {
                    self.logger.debug("Accessibility became available during retry window")
                    self.accessibilityRefreshTask = nil
                    return
                }
            }

            self.logger.debug("Accessibility refresh retry window expired after \(reason, privacy: .public)")
            self.accessibilityRefreshTask = nil
        }
    }

    private func isPermissionError(_ state: AppState) -> Bool {
        guard case let .error(message) = state else {
            return false
        }

        return message.hasPrefix("Grant accessibility")
            || message.hasPrefix("Grant microphone")
            || message.hasPrefix("Grant accessibility and microphone")
            || message.hasPrefix("Permissions updated")
    }

    private static func describe(permissions: PermissionSnapshot) -> String {
        "microphone=\(permissions.microphoneGranted), accessibility=\(permissions.accessibilityGranted)"
    }

    private static func describe(state: AppState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .recording:
            return "recording"
        case .transcribing:
            return "transcribing"
        case .inserting:
            return "inserting"
        case let .error(message):
            return "error(\(message))"
        }
    }
}

private enum PermissionPreparationResult {
    case ready
    case blocked(String)
}
