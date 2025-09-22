//
//  FireVoxApp.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import CoreData

@main
struct FireVoxApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var audioPlayerService = AudioPlayerService()
    @StateObject private var audioFileManager = AudioFileManager()
    @StateObject private var accessibilityManager = AccessibilityManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(audioPlayerService)
                .environmentObject(audioFileManager)
                .environmentObject(accessibilityManager)
        }
    }
}
