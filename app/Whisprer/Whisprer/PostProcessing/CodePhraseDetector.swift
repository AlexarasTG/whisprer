import Foundation

struct CodePhraseDetector {
    private static let maximumIdentifierWordCount = 5
    private static let punctuationAndWhitespace = CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines)
    private static let identifierSeparators = CharacterSet(charactersIn: "_-")
    private static let allowedIdentifierCharacters = CharacterSet.alphanumerics.union(identifierSeparators)

    private let developerDictionary: DeveloperDictionary

    init(developerDictionary: DeveloperDictionary) {
        self.developerDictionary = developerDictionary
    }

    func detectCodePhrases(in text: String) -> [CodePhraseMatch] {
        let tokens = tokenize(text)
        guard tokens.count >= 2 else {
            return []
        }

        var matches: [CodePhraseMatch] = []
        var index = 0

        while index < tokens.count {
            guard tokens[index].normalized == "the" else {
                index += 1
                continue
            }

            guard let match = parsePhrase(in: tokens, gateIndex: index) else {
                index += 1
                continue
            }

            matches.append(match)
            index = match.lastTokenIndex + 1
        }

        return matches
    }

    private func parsePhrase(in tokens: [Token], gateIndex: Int) -> CodePhraseMatch? {
        guard gateIndex + 1 < tokens.count else {
            return nil
        }

        if let directTokenMatch = parseDirectExtensionPhrase(in: tokens, gateIndex: gateIndex) {
            return directTokenMatch
        }

        if let spokenDotMatch = parseSpokenDotPhrase(in: tokens, gateIndex: gateIndex) {
            return spokenDotMatch
        }

        return nil
    }

    private func parseDirectExtensionPhrase(in tokens: [Token], gateIndex: Int) -> CodePhraseMatch? {
        let maximumLastTokenIndex = min(tokens.count - 1, gateIndex + Self.maximumIdentifierWordCount)

        for lastTokenIndex in (gateIndex + 1)...maximumLastTokenIndex {
            guard let splitToken = splitIdentifierAndExtension(from: tokens[lastTokenIndex].normalized) else {
                continue
            }

            let leadingIdentifierTokens = tokens[(gateIndex + 1)..<lastTokenIndex]
            let leadingWords = leadingIdentifierTokens.map(\.normalized).filter { !$0.isEmpty }
            guard !leadingWords.contains("the") else {
                continue
            }
            let trailingWords = identifierWords(from: splitToken.identifier) ?? [splitToken.identifier]
            let identifierWords = (leadingWords + trailingWords).filter { !$0.isEmpty }

            guard
                !identifierWords.isEmpty,
                identifierWords.count <= Self.maximumIdentifierWordCount
            else {
                continue
            }

            return CodePhraseMatch(
                range: tokens[gateIndex + 1].coreRange.lowerBound..<tokens[lastTokenIndex].coreRange.upperBound,
                identifierWords: identifierWords,
                canonicalExtension: splitToken.canonicalExtension,
                lastTokenIndex: lastTokenIndex
            )
        }

        return nil
    }

    private func parseSpokenDotPhrase(in tokens: [Token], gateIndex: Int) -> CodePhraseMatch? {
        let maximumDotIndex = min(tokens.count - 2, gateIndex + Self.maximumIdentifierWordCount + 1)
        var dotIndex = gateIndex + 1

        while dotIndex <= maximumDotIndex && tokens[dotIndex].normalized != "dot" {
            dotIndex += 1
        }

        guard dotIndex <= maximumDotIndex else {
            return nil
        }

        let identifierTokens = tokens[(gateIndex + 1)..<dotIndex]
        guard
            !identifierTokens.isEmpty,
            identifierTokens.count <= Self.maximumIdentifierWordCount
        else {
            return nil
        }

        let identifierWords = identifierTokens.map(\.normalized).filter { !$0.isEmpty }
        guard
            !identifierWords.isEmpty,
            !identifierWords.contains("the")
        else {
            return nil
        }

        let extensionToken = tokens[dotIndex + 1]
        guard let canonicalExtension = developerDictionary.canonicalExtension(for: extensionToken.normalized) else {
            return nil
        }

        return CodePhraseMatch(
            range: tokens[gateIndex + 1].coreRange.lowerBound..<extensionToken.coreRange.upperBound,
            identifierWords: identifierWords,
            canonicalExtension: canonicalExtension,
            lastTokenIndex: dotIndex + 1
        )
    }

    private func splitIdentifierAndExtension(from token: String) -> SplitIdentifierToken? {
        let components = token.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2 else {
            return nil
        }

        let identifier = String(components[0])
        let extensionToken = String(components[1])

        guard
            !identifier.isEmpty,
            let canonicalExtension = developerDictionary.canonicalExtension(for: extensionToken)
        else {
            return nil
        }

        return SplitIdentifierToken(
            identifier: identifier,
            canonicalExtension: canonicalExtension
        )
    }

    private func identifierWords(from identifier: String) -> [String]? {
        guard identifier.unicodeScalars.allSatisfy({ Self.allowedIdentifierCharacters.contains($0) }) else {
            return nil
        }

        if identifier.contains("_") {
            let words = identifier.split(separator: "_").map(String.init).filter { !$0.isEmpty }
            return words.isEmpty ? nil : words
        }

        if identifier.contains("-") {
            let words = identifier.split(separator: "-").map(String.init).filter { !$0.isEmpty }
            return words.isEmpty ? nil : words
        }

        let camelWords = splitCamelOrPascalCase(identifier)
        return camelWords.isEmpty ? nil : camelWords
    }

    private func splitCamelOrPascalCase(_ identifier: String) -> [String] {
        guard !identifier.isEmpty else {
            return []
        }

        var words: [String] = []
        var currentWord = String(identifier.first!)
        let characters = Array(identifier)

        for index in 1..<characters.count {
            let character = characters[index]
            let previousCharacter = characters[index - 1]
            let nextCharacter = index + 1 < characters.count ? characters[index + 1] : nil

            let startsNewWord =
                (character.isUppercase && previousCharacter.isLowercase) ||
                (character.isUppercase && previousCharacter.isUppercase && nextCharacter?.isLowercase == true)

            if startsNewWord {
                words.append(currentWord)
                currentWord = String(character)
            } else {
                currentWord.append(character)
            }
        }

        words.append(currentWord)
        return words
    }

    private func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var currentTokenStart: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            if text[index].isWhitespace {
                if let tokenStart = currentTokenStart {
                    let rawRange = tokenStart..<index
                    let coreRange = coreRange(in: text, for: rawRange)
                    tokens.append(
                        Token(
                            coreRange: coreRange,
                            normalized: String(text[coreRange]).lowercased()
                        )
                    )
                    consumeWhitespacePrefix(upTo: &index, in: text)
                    currentTokenStart = nil
                    continue
                }
            } else if currentTokenStart == nil {
                currentTokenStart = index
            }

            index = text.index(after: index)
        }

        if let tokenStart = currentTokenStart {
            let rawRange = tokenStart..<text.endIndex
            let coreRange = coreRange(in: text, for: rawRange)
            tokens.append(
                Token(
                    coreRange: coreRange,
                    normalized: String(text[coreRange]).lowercased()
                )
            )
        }

        return tokens
    }

    private func coreRange(in text: String, for rawRange: Range<String.Index>) -> Range<String.Index> {
        var lowerBound = rawRange.lowerBound
        var upperBound = rawRange.upperBound

        while lowerBound < upperBound, let scalar = text[lowerBound].unicodeScalars.first, Self.punctuationAndWhitespace.contains(scalar) {
            lowerBound = text.index(after: lowerBound)
        }

        while upperBound > lowerBound {
            let previousIndex = text.index(before: upperBound)
            guard let scalar = text[previousIndex].unicodeScalars.first, Self.punctuationAndWhitespace.contains(scalar) else {
                break
            }
            upperBound = previousIndex
        }

        return lowerBound..<upperBound
    }

    private func consumeWhitespacePrefix(upTo index: inout String.Index, in text: String) {
        while index < text.endIndex && text[index].isWhitespace {
            index = text.index(after: index)
        }
    }
}

struct CodePhraseMatch {
    let range: Range<String.Index>
    let identifierWords: [String]
    let canonicalExtension: String
    let lastTokenIndex: Int
}

private struct SplitIdentifierToken {
    let identifier: String
    let canonicalExtension: String
}

private struct Token {
    let coreRange: Range<String.Index>
    let normalized: String
}
