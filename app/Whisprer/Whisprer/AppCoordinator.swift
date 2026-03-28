import Combine
import Foundation

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

    init() {
        permissions = permissionManager.snapshot()
        hotkeyManager.onPressed = { [weak self] in
            self?.handleHotkeyPressed()
        }
        hotkeyManager.onReleased = { [weak self] in
            self?.handleHotkeyReleased()
        }
        hotkeyManager.startMonitoring()
    }

    func requestPermissions() {
        permissionManager.promptForAccessibilityAccess()

        Task {
            _ = await permissionManager.requestMicrophoneAccess()
            await MainActor.run {
                self.refreshPermissions()
            }
        }
    }

    func clearError() {
        if case .error = state {
            state = .idle
        }
    }

    func refreshPermissions() {
        permissions = permissionManager.snapshot()
    }

    private func handleHotkeyPressed() {
        Task {
            await startRecordingIfPossible()
        }
    }

    private func handleHotkeyReleased() {
        Task {
            await stopRecordingIfNeeded()
        }
    }

    private func startRecordingIfPossible() async {
        refreshPermissions()

        if case .recording = state {
            return
        }

        switch state {
        case .transcribing, .inserting:
            return
        case .idle, .error:
            break
        case .recording:
            return
        }

        switch await preparePermissionsForRecording() {
        case .ready:
            break
        case let .blocked(message):
            state = .error(message)
            return
        }

        do {
            try recorder.startRecording()
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func preparePermissionsForRecording() async -> PermissionPreparationResult {
        let initialPermissions = permissions
        let requestedAccessibility = !initialPermissions.accessibilityGranted
        let requestedMicrophone = !initialPermissions.microphoneGranted

        if requestedAccessibility {
            permissionManager.promptForAccessibilityAccess()
        }

        if requestedMicrophone {
            _ = await permissionManager.requestMicrophoneAccess()
        }

        refreshPermissions()

        guard permissions.readyForEndToEndFlow else {
            return .blocked(permissionGuidanceMessage())
        }

        if requestedAccessibility || requestedMicrophone {
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
            return
        }

        state = .transcribing

        do {
            let audioFileURL = try await recorder.stopRecording()
            let transcript = try await transcriptionEngine.transcribe(audioFileURL: audioFileURL)
            let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedTranscript.isEmpty else {
                state = .error("No speech was detected in the recording.")
                return
            }

            lastTranscript = trimmedTranscript
            state = .inserting
            try await textInsertionService.insert(text: trimmedTranscript)
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

private enum PermissionPreparationResult {
    case ready
    case blocked(String)
}
