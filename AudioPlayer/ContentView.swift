//
//  ContentView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import CoreData

enum AppView {
    case library
    // ORPHANED: case player - no longer used since player is now an overlay
    // case player
    case settings
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var audioFileManager: AudioFileManager
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var playlistManager: PlaylistManager
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var currentView: AppView = .library
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _playlistManager = StateObject(wrappedValue: PlaylistManager(context: context))
    }

    var body: some View {
        ZStack {
            // Main content layer
            Group {
                switch currentView {
                case .library:
                    LibraryGridView(
                        navigateToPlayer: { /* Player is now a slide-up overlay */ },
                        navigateToSettings: { currentView = .settings }
                    )
                    
                // ORPHANED CODE: .player case is no longer used since player is now an overlay
                /*
                case .player:
                    // This case is no longer used since player is now an overlay
                    LibraryGridView(
                        navigateToPlayer: { },
                        navigateToSettings: { currentView = .settings }
                    )
                */
                    
                case .settings:
                    NavigationStack {
                        SettingsView()
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Library") {
                                        currentView = .library
                                    }
                                }
                            }
                    }
                }
            }
            
            // Slide-up player overlay (only show when there's an audio file)
            if audioPlayerService.currentAudioFile != nil {
                SlideUpPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environmentObject(settingsManager)
        .environmentObject(playlistManager)
        .environmentObject(accessibilityManager)
        .environmentObject(localizationManager)
        .environment(\.managedObjectContext, viewContext)
        .accentColor(accessibilityManager.highContrastColor(base: .blue, highContrast: .primary))
        .visualAccessibility(reducedMotion: true)
        .onAppear {
            // Set up the connection between AudioPlayerService and PlaylistManager
            audioPlayerService.setPlaylistManager(playlistManager)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
        .environmentObject(AudioFileManager())
        .environmentObject(SettingsManager())
        .environmentObject(AccessibilityManager())
        .environmentObject(LocalizationManager.shared)
}
