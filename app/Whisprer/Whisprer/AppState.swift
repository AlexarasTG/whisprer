import Foundation

enum AppState {
    case idle
    case recording
    case transcribing
    case inserting
    case error(String)

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .inserting:
            return "Inserting Text"
        case .error:
            return "Attention Needed"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "Hold Right Option to dictate."
        case .recording:
            return "Release Right Option to transcribe."
        case .transcribing:
            return "Running local Whisper transcription."
        case .inserting:
            return "Pasting transcript into the active app."
        case let .error(message):
            return message
        }
    }

    var menuBarIcon: String {
        switch self {
        case .idle:
            return "waveform.badge.mic"
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        case .inserting:
            return "doc.on.clipboard"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
