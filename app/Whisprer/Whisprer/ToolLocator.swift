import Foundation
import OSLog

enum ToolLocator {
    private nonisolated static let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "ToolLocator")
    private nonisolated static let whisperCLIKey = "WHISPRER_WHISPER_CLI_URL"
    private nonisolated static let whisperModelKey = "WHISPRER_WHISPER_MODEL_URL"

    nonisolated static func whisperCLIURL() throws -> URL {
        try configuredURL(
            for: whisperCLIKey,
            missingMessage: "Missing \(whisperCLIKey). Set it to a readable file URL or absolute path for whisper-cli."
        )
    }

    nonisolated static func modelURL() throws -> URL {
        try configuredURL(
            for: whisperModelKey,
            missingMessage: "Missing \(whisperModelKey). Set it to a readable file URL or absolute path for the Whisper model."
        )
    }

    private nonisolated static func configuredURL(for key: String, missingMessage: String) throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        guard let rawValue = environment[key], !rawValue.isEmpty else {
            logger.error("Environment key \(key, privacy: .public) is not set")
            throw ToolLocatorError.missingDependency(missingMessage)
        }

        let resolvedURL = resolveURL(from: rawValue)
        logger.debug("Resolved environment key \(key, privacy: .public) to \(resolvedURL.path, privacy: .public)")

        guard FileManager.default.isReadableFile(atPath: resolvedURL.path) else {
            logger.error("Configured path for \(key, privacy: .public) is not readable: \(resolvedURL.path, privacy: .public)")
            throw ToolLocatorError.missingDependency("Configured path for \(key) is not readable: \(resolvedURL.path)")
        }

        return resolvedURL
    }

    private nonisolated static func resolveURL(from rawValue: String) -> URL {
        if let url = URL(string: rawValue), url.isFileURL {
            return url.standardizedFileURL
        }

        return URL(fileURLWithPath: rawValue).standardizedFileURL
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
