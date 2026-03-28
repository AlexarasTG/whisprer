import AVFoundation
import Foundation

final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?

    func startRecording() throws {
        guard recorder == nil else {
            throw AudioRecorderError.alreadyRecording
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisprer-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw AudioRecorderError.startFailed
        }

        self.recorder = recorder
        outputURL = url
    }

    func stopRecording() async throws -> URL {
        guard let recorder, let outputURL else {
            throw AudioRecorderError.notRecording
        }

        recorder.stop()
        self.recorder = nil
        self.outputURL = nil

        try await Task.sleep(nanoseconds: 150_000_000)

        return outputURL
    }
}

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case startFailed
    case notRecording

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress."
        case .startFailed:
            return "Unable to start microphone recording."
        case .notRecording:
            return "No recording is currently in progress."
        }
    }
}
