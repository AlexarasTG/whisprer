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

        guard permissions.accessibilityGranted else {
            permissionManager.promptForAccessibilityAccess()
            state = .error("Accessibility permission is required for the global hotkey and paste automation.")
            refreshPermissions()
            return
        }

        let microphoneGranted = await permissionManager.requestMicrophoneAccess()
        refreshPermissions()

        guard microphoneGranted else {
            state = .error("Microphone permission is required to record audio.")
            return
        }

        do {
            try recorder.startRecording()
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
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
