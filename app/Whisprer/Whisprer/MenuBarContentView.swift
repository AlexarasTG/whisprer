import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(coordinator.state.title, systemImage: coordinator.state.menuBarIcon)
                .font(.headline)

            Text(coordinator.state.detail)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            permissionSection

            if !coordinator.lastTranscript.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Transcript")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(coordinator.lastTranscript)
                        .font(.callout)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
            }

            Divider()

            HStack {
                Button("Refresh Status") {
                    coordinator.refreshPermissions()
                }

                if case .error = coordinator.state {
                    Button("Clear Error") {
                        coordinator.clearError()
                    }
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.caption)
                .foregroundStyle(.secondary)

            permissionRow(title: "Microphone", granted: coordinator.permissions.microphoneGranted)
            permissionRow(title: "Accessibility", granted: coordinator.permissions.accessibilityGranted)

            if !coordinator.permissions.readyForEndToEndFlow {
                Button("Request Permissions") {
                    coordinator.requestPermissions()
                }
            }
        }
    }

    private func permissionRow(title: String, granted: Bool) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(title)
        }
        .font(.callout)
    }
}
