import Foundation

enum ToolLocator {
    nonisolated static func whisperCLIURL() throws -> URL {
        try locate(relativePath: "tools/whisper-cli", missingMessage: "Unable to find ./tools/whisper-cli.")
    }

    nonisolated static func modelURL() throws -> URL {
        try locate(relativePath: "models/ggml-base.en.bin", missingMessage: "Unable to find ./models/ggml-base.en.bin.")
    }

    private nonisolated static func locate(relativePath: String, missingMessage: String) throws -> URL {
        for baseURL in candidateBaseURLs() {
            let candidate = baseURL.appendingPathComponent(relativePath)
            if FileManager.default.isReadableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw ToolLocatorError.missingDependency(missingMessage)
    }

    private nonisolated static func candidateBaseURLs() -> [URL] {
        var urls: [URL] = []
        let fileManager = FileManager.default

        urls.append(contentsOf: ancestorURLs(for: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)))

        if let pwd = ProcessInfo.processInfo.environment["PWD"] {
            urls.append(contentsOf: ancestorURLs(for: URL(fileURLWithPath: pwd, isDirectory: true)))
        }

        if let resourceURL = Bundle.main.resourceURL {
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
