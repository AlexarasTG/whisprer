import AppKit
import ApplicationServices
import Carbon
import Foundation

@MainActor
final class TextInsertionService {
    func insert(text: String) async throws {
        guard AXIsProcessTrusted() else {
            throw TextInsertionError.accessibilityNotGranted
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        do {
            pasteboard.clearContents()
            guard pasteboard.setString(text, forType: .string) else {
                throw TextInsertionError.copyFailed
            }

            try postPasteShortcut()
            try await Task.sleep(nanoseconds: 250_000_000)
            snapshot.restore(to: pasteboard)
        } catch {
            snapshot.restore(to: pasteboard)
            throw error
        }
    }

    private func postPasteShortcut() throws {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDownEvent = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
            ),
            let keyUpEvent = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
            )
        else {
            throw TextInsertionError.pasteFailed
        }

        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }
}

private struct PasteboardSnapshot {
    private let items: [PasteboardItemSnapshot]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { PasteboardItemSnapshot(item: $0) }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        for item in items {
            let pasteboardItem = NSPasteboardItem()
            item.values.forEach { type, data in
                pasteboardItem.setData(data, forType: type)
            }
            pasteboard.writeObjects([pasteboardItem])
        }
    }
}

private struct PasteboardItemSnapshot {
    let values: [NSPasteboard.PasteboardType: Data]

    init(item: NSPasteboardItem) {
        var values: [NSPasteboard.PasteboardType: Data] = [:]

        for type in item.types {
            if let data = item.data(forType: type) {
                values[type] = data
            }
        }

        self.values = values
    }
}

enum TextInsertionError: LocalizedError {
    case accessibilityNotGranted
    case copyFailed
    case pasteFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is required to paste into the active app."
        case .copyFailed:
            return "Unable to copy the transcript to the pasteboard."
        case .pasteFailed:
            return "Unable to send the paste shortcut to the active app."
        }
    }
}
