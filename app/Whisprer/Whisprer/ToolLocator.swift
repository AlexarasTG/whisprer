import Foundation
import OSLog

enum ToolLocator {
    private nonisolated static let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "ToolLocator")

    nonisolated static func whisperCLIURL() throws -> URL {
        try locate(relativePath: "tools/whisper-cli", missingMessage: "Unable to find ./tools/whisper-cli.")
    }

    nonisolated static func modelURL() throws -> URL {
        try locate(relativePath: "models/ggml-base.en.bin", missingMessage: "Unable to find ./models/ggml-base.en.bin.")
    }

    private nonisolated static func locate(relativePath: String, missingMessage: String) throws -> URL {
        let baseURLs = candidateBaseURLs()
        logger.debug("Locating \(relativePath, privacy: .public) from \(baseURLs.count) candidate roots")

        for baseURL in baseURLs {
            let candidate = baseURL.appendingPathComponent(relativePath)
            logger.debug("Trying candidate \(candidate.path, privacy: .public)")
            if FileManager.default.isReadableFile(atPath: candidate.path) {
                logger.debug("Resolved \(relativePath, privacy: .public) to \(candidate.path, privacy: .public)")
                return candidate
            }
        }

        logger.error("Failed to resolve \(relativePath, privacy: .public)")
        throw ToolLocatorError.missingDependency(missingMessage)
    }

    private nonisolated static func candidateBaseURLs() -> [URL] {
        var urls: [URL] = []
        let fileManager = FileManager.default

        let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        logger.debug("Current directory root: \(currentDirectoryURL.path, privacy: .public)")
        urls.append(contentsOf: ancestorURLs(for: currentDirectoryURL))

        if let pwd = ProcessInfo.processInfo.environment["PWD"] {
            let pwdURL = URL(fileURLWithPath: pwd, isDirectory: true)
            logger.debug("PWD root: \(pwdURL.path, privacy: .public)")
            urls.append(contentsOf: ancestorURLs(for: pwdURL))
        }

        if let resourceURL = Bundle.main.resourceURL {
            logger.debug("Bundle resource root: \(resourceURL.path, privacy: .public)")
            urls.append(contentsOf: ancestorURLs(for: resourceURL))
        }

        return Array(NSOrderedSet(array: urls)) as? [URL] ?? urls
    }

    private nonisolated static func ancestorURLs(for url: URL) -> [URL] {
        var ancestors: [URL] = []
        var currentURL = url.standardizedFileURL

        while true {
            ancestors.append(currentURL)
            let parentURL = currentURL.deletingLastPathComponent()

            if parentURL.path == currentURL.path {
                break
            }

            currentURL = parentURL
        }

        return ancestors
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
