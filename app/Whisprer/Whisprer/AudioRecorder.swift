import AVFoundation
import Foundation
import OSLog

final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "AudioRecorder")

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

        logger.debug("Creating recorder for file \(url.path, privacy: .public)")
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw AudioRecorderError.startFailed
        }

        self.recorder = recorder
        outputURL = url
        logger.debug("Recording started")
    }

    func stopRecording() async throws -> URL {
        guard let recorder, let outputURL else {
            throw AudioRecorderError.notRecording
        }

        logger.debug("Stopping recording for file \(outputURL.path, privacy: .public)")
        recorder.stop()
        self.recorder = nil
        self.outputURL = nil

        try await Task.sleep(nanoseconds: 150_000_000)

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.int64Value ?? -1
        logger.debug("Recording stopped. Output size=\(fileSize) bytes")

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
