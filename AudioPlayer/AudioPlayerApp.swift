//
//  FireVoxApp.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import CoreData

@main
struct AudioPlayerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var audioPlayerService = AudioPlayerService()
    @StateObject private var audioFileManager = AudioFileManager()
    @StateObject private var accessibilityManager = AccessibilityManager()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(audioPlayerService)
                .environmentObject(audioFileManager)
                .environmentObject(accessibilityManager)
                .environmentObject(localizationManager)
                .environmentObject(themeManager)
                .environment(\.appTheme, AppTheme(isDark: themeManager.isDarkMode))
        }
    }
}
