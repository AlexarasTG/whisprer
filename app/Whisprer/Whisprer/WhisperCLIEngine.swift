import Foundation

protocol TranscriptionEngine {
    func transcribe(audioFileURL: URL) async throws -> String
}

struct WhisperCLIEngine: TranscriptionEngine {
    func transcribe(audioFileURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let executableURL = try ToolLocator.whisperCLIURL()
            let modelURL = try ToolLocator.modelURL()

            let process = Process()
            process.executableURL = executableURL
            process.arguments = [
                "--file", audioFileURL.path,
                "--model", modelURL.path,
                "--language", "en",
                "--no-timestamps",
                "--no-prints",
                "--vad"
            ]

            let standardOutput = Pipe()
            let standardError = Pipe()
            process.standardOutput = standardOutput
            process.standardError = standardError

            try process.run()
            process.waitUntilExit()

            let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

            let output = String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let errorOutput = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

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
