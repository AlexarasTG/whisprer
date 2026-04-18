import AVFoundation
import ApplicationServices
import Foundation

struct PermissionSnapshot {
    let microphoneGranted: Bool
    let accessibilityGranted: Bool

    var readyForEndToEndFlow: Bool {
        microphoneGranted && accessibilityGranted
    }
}

final class PermissionManager {
    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphoneGranted: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            accessibilityGranted: AXIsProcessTrusted()
        )
    }

    func requestMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func promptForAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
