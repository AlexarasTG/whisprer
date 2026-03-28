//
//  WhisprerApp.swift
//  Whisprer
//
//  Created by Alex Dritsas on 22/03/2026.
//

import SwiftUI

@main
struct WhisprerApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(coordinator: coordinator)
        } label: {
            Label("Whisprer", systemImage: coordinator.state.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
