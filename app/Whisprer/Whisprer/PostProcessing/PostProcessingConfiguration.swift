import Foundation

struct PostProcessingConfiguration {
    let developerDictionary: DeveloperDictionary
    let defaultIdentifierStyleByExtension: [String: IdentifierStyle]

    static let `default` = PostProcessingConfiguration(
        developerDictionary: .default,
        defaultIdentifierStyleByExtension: [
            "java": .pascalCase,
            "kt": .pascalCase,
            "swift": .pascalCase,
            "py": .snakeCase,
            "rs": .snakeCase,
            "js": .snakeCase,
            "ts": .snakeCase,
            "jsx": .snakeCase,
            "tsx": .snakeCase,
            "json": .kebabCase,
            "yaml": .kebabCase,
            "yml": .kebabCase,
            "xml": .kebabCase,
            "log": .kebabCase,
            "md": .kebabCase,
        ]
    )

    func identifierStyle(for extensionName: String) -> IdentifierStyle {
        defaultIdentifierStyleByExtension[extensionName, default: .camelCase]
    }
}

enum IdentifierStyle {
    case pascalCase
    case camelCase
    case snakeCase
    case kebabCase
}
