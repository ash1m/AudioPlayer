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
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            RootView(
                audioPlayerService: audioPlayerService,
                audioFileManager: audioFileManager,
                accessibilityManager: accessibilityManager,
                themeManager: themeManager
            )
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

private struct RootView: View {
    @ObservedObject var audioPlayerService: AudioPlayerService
    @ObservedObject var audioFileManager: AudioFileManager
    @ObservedObject var accessibilityManager: AccessibilityManager
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        print("🎨 [RootView] body computed with isDarkMode: \(themeManager.isDarkMode)")
        return ContentView()
            .environmentObject(audioPlayerService)
            .environmentObject(audioFileManager)
            .environmentObject(accessibilityManager)
            .environmentObject(themeManager)
            // Update AppTheme environment when themeManager.isDarkMode changes
            .environment(\.appTheme, AppTheme(isDark: themeManager.isDarkMode))
            // Force SwiftUI to use the correct color scheme based on theme
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
}
