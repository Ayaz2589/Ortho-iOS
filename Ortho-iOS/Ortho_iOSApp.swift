//
//  Ortho_iOSApp.swift
//  Ortho-iOS
//
//  Created by Ayaz Uddin on 5/18/26.
//

import SwiftUI

@main
struct Ortho_iOSApp: App {
    @State private var appState = AppState()
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue

    init() {
        AppFont.register()
    }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.session != nil {
                    RootTabView()
                } else {
                    SignInView()
                }
            }
            .environment(appState)
            .preferredColorScheme(appearance.colorScheme)
            .task {
                // First emission carries the SDK's restored session (or
                // nil), so this doubles as launch-time session restore.
                await appState.observeAuthChanges()
            }
        }
    }
}
