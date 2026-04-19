import Foundation

struct DeveloperDictionary {
    let extensionAliases: [String: String]

    static let `default` = DeveloperDictionary(
        extensionAliases: [
            "java": "java",
            "kt": "kt",
            "kotlin": "kt",
            "swift": "swift",
            "py": "py",
            "python": "py",
            "rs": "rs",
            "rust": "rs",
            "json": "json",
            "log": "log",
            "yaml": "yaml",
            "yml": "yml",
            "xml": "xml",
            "md": "md",
            "markdown": "md",
            "js": "js",
            "javascript": "js",
            "ts": "ts",
            "typescript": "ts",
            "jsx": "jsx",
            "tsx": "tsx",
        ]
    )

    func canonicalExtension(for token: String) -> String? {
        extensionAliases[token.normalizedDeveloperToken]
    }
}

private extension String {
    var normalizedDeveloperToken: String {
        trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines)).lowercased()
    }
}
