import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            permissionSection

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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(statusColor.opacity(0.14))
                        .frame(width: 36, height: 36)

                    Image("MenuBarIcon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Whisprer")
                        .font(.headline)

                    statusBadge
                }

                Spacer()

                Image(systemName: coordinator.state.menuBarIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
            }

            Text(coordinator.state.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.caption)
                .foregroundStyle(.secondary)

            if coordinator.permissions.readyForEndToEndFlow {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("System Access Ready")
                        .fontWeight(.medium)
                }
                .font(.callout)
            } else {
                permissionRow(title: "Microphone", granted: coordinator.permissions.microphoneGranted)
                permissionRow(title: "Accessibility", granted: coordinator.permissions.accessibilityGranted)
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

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            Text(coordinator.state.title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.14))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch coordinator.state {
        case .idle:
            return .secondary
        case .recording:
            return .green
        case .transcribing:
            return .yellow
        case .inserting:
            return .orange
        case .error:
            return .red
        }
    }
}
