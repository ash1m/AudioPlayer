//
//  AudioPlayerApp.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import CoreData

@main
struct AudioPlayerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
