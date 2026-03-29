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
    private let textInsertionService = TextInsertionService()
    private let hotkeyManager = RightOptionHotkeyManager()
    private let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "AppCoordinator")

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
    }

    func requestPermissions() {
        logger.debug("Manual permission request triggered")
        permissionManager.promptForAccessibilityAccess()

        Task {
            _ = await permissionManager.requestMicrophoneAccess()
            await MainActor.run {
                self.refreshPermissions()
                self.logger.debug("Permissions after manual request: \(Self.describe(permissions: self.permissions), privacy: .public)")
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

        switch await preparePermissionsForRecording() {
        case .ready:
            logger.debug("Permissions ready for recording")
            break
        case let .blocked(message):
            logger.debug("Recording blocked by permissions: \(message, privacy: .public)")
            setState(.error(message))
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

    private func preparePermissionsForRecording() async -> PermissionPreparationResult {
        let initialPermissions = permissions
        let requestedAccessibility = !initialPermissions.accessibilityGranted
        let requestedMicrophone = !initialPermissions.microphoneGranted

        logger.debug(
            "Preparing permissions. Current snapshot: \(Self.describe(permissions: initialPermissions), privacy: .public)"
        )

        if requestedAccessibility {
            logger.debug("Requesting accessibility permission")
            permissionManager.promptForAccessibilityAccess()
        }

        if requestedMicrophone {
            logger.debug("Requesting microphone permission")
            _ = await permissionManager.requestMicrophoneAccess()
        }

        refreshPermissions()

        guard permissions.readyForEndToEndFlow else {
            logger.debug("Permissions still incomplete after request: \(Self.describe(permissions: self.permissions), privacy: .public)")
            return .blocked(permissionGuidanceMessage())
        }

        if requestedAccessibility || requestedMicrophone {
            logger.debug("Permissions changed during this attempt; requiring a fresh hotkey press")
            return .blocked("Permissions updated. Press Right Option again to start dictation.")
        }

        return .ready
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
            logger.debug("Recorder returned audio file: \(audioFileURL.path, privacy: .public)")
            logger.debug("Invoking transcription engine")
            let transcript = try await transcriptionEngine.transcribe(audioFileURL: audioFileURL)
            let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.debug("Transcription completed. Character count=\(trimmedTranscript.count)")

            guard !trimmedTranscript.isEmpty else {
                logger.error("Transcript was empty after trimming")
                setState(.error("No speech was detected in the recording."))
                return
            }

            lastTranscript = trimmedTranscript
            logger.debug("Starting text insertion")
            setState(.inserting)
            try await textInsertionService.insert(text: trimmedTranscript)
            logger.debug("Text insertion completed")
            setState(.idle)
        } catch {
            logger.error("End-to-end flow failed: \(error.localizedDescription, privacy: .public)")
            setState(.error(error.localizedDescription))
        }
    }

    private func setState(_ newState: AppState) {
        logger.debug("State transition: \(Self.describe(state: self.state), privacy: .public) -> \(Self.describe(state: newState), privacy: .public)")
        state = newState
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
