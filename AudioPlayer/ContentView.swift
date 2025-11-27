//
//  ContentView.swift
//  FireVox
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
                if currentView == .settings {
                    NavigationStack {
                        SettingsView()
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Back") {
                                        currentView = .library
                                    }
                                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                                    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
                                }
                            }
                    }
                } else {
                    LibraryGridView(
                        navigateToPlayer: { /* Player is now a slide-up overlay */ },
                        navigateToSettings: { currentView = .settings }
                    )
                }
            }
            
            // Slide-up player overlay
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

