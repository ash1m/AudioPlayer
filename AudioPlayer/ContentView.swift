//
//  ContentView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @StateObject private var audioPlayerService = AudioPlayerService()
    @StateObject private var audioFileManager = AudioFileManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var playlistManager: PlaylistManager
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var selectedTab = 0
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _playlistManager = StateObject(wrappedValue: PlaylistManager(context: context))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryGridView(navigateToPlayer: navigateToPlayer)
                .tabItem {
                    Image(systemName: "book")
                        .accessibilityHidden(true)
                    Text(LocalizationManager.shared.tabLibrary)
                        .dynamicTypeSupport(.caption)
                }
                .tag(0)
                .accessibilityLabel("Library tab")
                .accessibilityHint("Browse your audio library")
                .tabFocus(name: "Library", isActive: selectedTab == 0)
            
            PlaylistView()
                .tabItem {
                    Image(systemName: "music.note.list")
                        .accessibilityHidden(true)
                    Text(LocalizationManager.shared.localizedString("tab.playlist"))
                        .dynamicTypeSupport(.caption)
                }
                .tag(1)
                .accessibilityLabel("Playlist tab")
                .accessibilityHint("Create and manage playlists")
                .tabFocus(name: "Playlist", isActive: selectedTab == 1)
            
            AudioPlayerView()
                .tabItem {
                    Image(systemName: "play.circle")
                        .accessibilityHidden(true)
                    Text(LocalizationManager.shared.tabPlayer)
                        .dynamicTypeSupport(.caption)
                }
                .tag(2)
                .accessibilityLabel("Player tab")
                .accessibilityHint("Audio player controls")
                .tabFocus(name: "Player", isActive: selectedTab == 2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                        .accessibilityHidden(true)
                    Text(LocalizationManager.shared.tabSettings)
                        .dynamicTypeSupport(.caption)
                }
                .tag(3)
                .accessibilityLabel("Settings tab")
                .accessibilityHint("App settings and preferences")
                .tabFocus(name: "Settings", isActive: selectedTab == 3)
        }
        .environmentObject(audioPlayerService)
        .environmentObject(audioFileManager)
        .environmentObject(settingsManager)
        .environmentObject(playlistManager)
        .environmentObject(accessibilityManager)
        .environment(\.managedObjectContext, viewContext)
        .accentColor(accessibilityManager.highContrastColor(base: .blue, highContrast: .primary))
        .visualAccessibility(reducedMotion: true)
        .onAppear {
            // Set up the connection between AudioPlayerService and PlaylistManager
            audioPlayerService.setPlaylistManager(playlistManager)
        }
    }
    
    private func navigateToPlayer() {
        selectedTab = 2
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
        .environmentObject(AudioFileManager())
        .environmentObject(SettingsManager())
        .environmentObject(AccessibilityManager())
}
