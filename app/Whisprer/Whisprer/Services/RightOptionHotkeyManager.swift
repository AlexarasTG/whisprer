import AppKit
import Carbon
import Foundation
import IOKit.hidsystem

final class RightOptionHotkeyManager {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isPressed = false

    func startMonitoring() {
        guard globalMonitor == nil, localMonitor == nil else {
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
            return event
        }
    }

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    private func handle(event: NSEvent) {
        guard event.type == .flagsChanged, event.keyCode == UInt16(kVK_RightOption) else {
            return
        }

        let rightOptionPressed = (event.modifierFlags.rawValue & UInt(NX_DEVICERALTKEYMASK)) != 0

        guard rightOptionPressed != isPressed else {
            return
        }

        isPressed = rightOptionPressed

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            if rightOptionPressed {
                self.onPressed?()
            } else {
                self.onReleased?()
            }
        }
    }
}
