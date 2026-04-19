import Foundation
import OSLog

struct TranscriptPostProcessor {
    private let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "TranscriptPostProcessor")
    private let configuration: PostProcessingConfiguration
    private let detector: CodePhraseDetector
    private let identifierFormatter = IdentifierFormatter()

    init(configuration: PostProcessingConfiguration = .default) {
        self.configuration = configuration
        self.detector = CodePhraseDetector(developerDictionary: configuration.developerDictionary)
    }

    func process(_ transcript: String) -> String {
        let matches = detector.detectCodePhrases(in: transcript)
        guard !matches.isEmpty else {
            return transcript
        }

        var processedTranscript = transcript
        for match in matches.reversed() {
            let identifierStyle = configuration.identifierStyle(for: match.canonicalExtension)
            let formattedIdentifier = identifierFormatter.format(words: match.identifierWords, style: identifierStyle)
            guard !formattedIdentifier.isEmpty else {
                continue
            }

            let replacement = "@" + formattedIdentifier + "." + match.canonicalExtension
            logger.debug(
                """
                Post-processing match: words=\(match.identifierWords.joined(separator: " "), privacy: .public), extension=\(match.canonicalExtension, privacy: .public), style=\(Self.describe(style: identifierStyle), privacy: .public), replacement=\(replacement, privacy: .public)
                """
            )
            processedTranscript.replaceSubrange(match.range, with: replacement)
        }

        return processedTranscript
    }

    private static func describe(style: IdentifierStyle) -> String {
        switch style {
        case .pascalCase:
            return "pascalCase"
        case .camelCase:
            return "camelCase"
        case .snakeCase:
            return "snakeCase"
        case .kebabCase:
            return "kebabCase"
        }
    }
}
