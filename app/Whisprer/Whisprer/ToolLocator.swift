import Foundation
import OSLog

enum ToolLocator {
    private nonisolated static let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "ToolLocator")
    private nonisolated static let runtimeDirectoryName = "WhisperRuntime"
    private nonisolated static let whisperCLIName = "whisper-cli"
    private nonisolated static let whisperModelName = "ggml-base.en.bin"

    nonisolated static func whisperCLIURL() throws -> URL {
        try bundledURL(
            fileName: whisperCLIName,
            missingMessage: "Whisper CLI is not bundled with this app build. Missing tools/whisper-cli."
        )
    }

    nonisolated static func modelURL() throws -> URL {
        try bundledURL(
            fileName: whisperModelName,
            missingMessage: "Whisper model is not bundled with this app build. Missing models/ggml-base.en.bin."
        )
    }

    private nonisolated static func bundledURL(fileName: String, missingMessage: String) throws -> URL {
        guard let resourcesURL = Bundle.main.resourceURL else {
            logger.error("App bundle has no resource URL")
            throw ToolLocatorError.missingDependency(missingMessage)
        }

        let resolvedURL = resourcesURL
            .appendingPathComponent(runtimeDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)

        guard FileManager.default.isReadableFile(atPath: resolvedURL.path) else {
            logger.error("Bundled runtime asset is not readable: \(resolvedURL.path, privacy: .public)")
            throw ToolLocatorError.missingDependency(missingMessage)
        }

        logger.debug("Resolved bundled runtime asset to \(resolvedURL.path, privacy: .public)")
        return resolvedURL
    }
}

enum ToolLocatorError: LocalizedError {
    case missingDependency(String)

    var errorDescription: String? {
        switch self {
        case let .missingDependency(message):
            return message
        }
    }
}
