//
//  WhisprerApp.swift
//  Whisprer
//
//  Created by Alex Dritsas on 22/03/2026.
//

import AppKit
import Foundation
import OSLog
import SwiftUI

@main
struct WhisprerApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        SingleInstanceGuard.terminateIfAnotherInstanceIsRunning()
        _coordinator = StateObject(wrappedValue: AppCoordinator())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(coordinator: coordinator)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("Whisprer")
        }
        .menuBarExtraStyle(.window)
    }
}

private enum SingleInstanceGuard {
    private static let logger = Logger(subsystem: "com.alexarasTG.Whisprer", category: "SingleInstanceGuard")

    static func terminateIfAnotherInstanceIsRunning() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }

        guard !otherInstances.isEmpty else {
            return
        }

        logger.error("Another Whisprer instance is already running. Exiting duplicate process.")
        exit(EXIT_SUCCESS)
    }
}
