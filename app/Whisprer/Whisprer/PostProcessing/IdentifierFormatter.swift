import Foundation

struct IdentifierFormatter {
    func format(words: [String], style: IdentifierStyle) -> String {
        let sanitizedWords = words
            .map(\.identifierWord)
            .filter { !$0.isEmpty }

        guard !sanitizedWords.isEmpty else {
            return ""
        }

        switch style {
        case .pascalCase:
            return sanitizedWords
                .map { $0.capitalizedIdentifierWord }
                .joined()
        case .camelCase:
            let head = sanitizedWords[0].lowercased()
            let tail = sanitizedWords.dropFirst().map { $0.capitalizedIdentifierWord }.joined()
            return head + tail
        case .snakeCase:
            return sanitizedWords
                .map { $0.lowercased() }
                .joined(separator: "_")
        case .kebabCase:
            return sanitizedWords
                .map { $0.lowercased() }
                .joined(separator: "-")
        }
    }
}

private extension String {
    static let identifierWordCharacterSet = CharacterSet.alphanumerics

    var identifierWord: String {
        unicodeScalars
            .filter { Self.identifierWordCharacterSet.contains($0) }
            .map(String.init)
            .joined()
    }

    var capitalizedIdentifierWord: String {
        let lowercasedWord = lowercased()
        guard let firstCharacter = lowercasedWord.first else {
            return lowercasedWord
        }

        return String(firstCharacter).uppercased() + lowercasedWord.dropFirst()
    }
}
