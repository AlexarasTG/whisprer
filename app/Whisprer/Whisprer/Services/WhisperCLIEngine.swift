import Foundation
import OSLog

protocol TranscriptionEngine {
    func transcribe(audioFileURL: URL) async throws -> String
}

struct WhisperCLIEngine: TranscriptionEngine {
    private nonisolated static let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "WhisperCLIEngine")

    func transcribe(audioFileURL: URL) async throws -> String {
        Self.logger.debug("Preparing detached transcription task for file \(audioFileURL.path, privacy: .public)")
        return try await Task.detached(priority: .userInitiated) {
            Self.logger.debug("Entered detached transcription task")
            Self.logger.debug("Resolving whisper executable path")
            let executableURL = try ToolLocator.whisperCLIURL()
            Self.logger.debug("Resolved whisper executable path to \(executableURL.path, privacy: .public)")
            Self.logger.debug("Resolving whisper model path")
            let modelURL = try ToolLocator.modelURL()
            Self.logger.debug("Resolved whisper model path to \(modelURL.path, privacy: .public)")
            let arguments = [
                "--file", audioFileURL.path,
                "--model", modelURL.path,
                "--language", "en",
                "--no-timestamps",
                "--no-prints",
                "--no-gpu"
            ]

            Self.logger.debug("Starting transcription for file \(audioFileURL.path, privacy: .public)")
            Self.logger.debug("Using executable \(executableURL.path, privacy: .public)")
            Self.logger.debug("Using model \(modelURL.path, privacy: .public)")

            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let standardOutput = Pipe()
            let standardError = Pipe()
            process.standardOutput = standardOutput
            process.standardError = standardError

            let startedAt = Date()
            try process.run()
            Self.logger.debug("whisper-cli launched with pid \(process.processIdentifier)")
            process.waitUntilExit()
            let duration = Date().timeIntervalSince(startedAt)

            let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

            let output = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let errorOutput = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

            Self.logger.debug(
                "whisper-cli exited with status \(process.terminationStatus) after \(duration, format: .fixed(precision: 2))s"
            )

            if !errorOutput.isEmpty {
                Self.logger.debug("whisper-cli stderr: \(errorOutput, privacy: .public)")
            }

            if !output.isEmpty {
                Self.logger.debug("whisper-cli stdout length=\(output.count)")
            }

            guard process.terminationStatus == 0 else {
                throw WhisperCLIEngineError.commandFailed(errorOutput.isEmpty ? "whisper-cli exited with status \(process.terminationStatus)." : errorOutput)
            }

            return output
        }.value
    }
}

enum WhisperCLIEngineError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(message):
            return message
        }
    }
}
