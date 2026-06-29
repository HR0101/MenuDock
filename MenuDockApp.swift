//
//  MenuDockApp.swift
//  MenuDock
//

import SwiftUI
import SwiftData

@main
struct MenuDockApp: App {
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ShortcutApp.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra("MenuDock", systemImage: "square.grid.2x2") {
            ContentView()
                .modelContainer(MenuDockApp.sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}
