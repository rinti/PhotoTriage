//
//  PhotoTriageApp.swift
//  PhotoTriage
//

import SwiftUI

@main
struct PhotoTriageApp: App {
    var body: some Scene {
        WindowGroup {
            MainMenuView()
        }
        .defaultSize(width: 500, height: 400)

        Settings {
            SettingsView()
        }
    }
}
