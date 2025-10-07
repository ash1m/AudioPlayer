//
//  PlaylistView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/20.
//

import SwiftUI
import CoreData

struct PlaylistView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    @State private var isShowingAddFilesSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if playlistManager.getPlaylistCount() == 0 {
                    // Empty state
                    emptyStateView
                } else {
                    // Playlist content
                    playlistContentView
                }
            }
        .navigationTitle("Playlist")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityLabel("Playlist with \(playlistManager.getPlaylistCount()) track\(playlistManager.getPlaylistCount() == 1 ? "" : "s")")
        .onAppear {
            // Announce when entering playlist view
            accessibilityManager.announceScreenChange()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let count = playlistManager.getPlaylistCount()
                let announcement = count == 0 ? "Empty playlist" : "Playlist with \(count) track\(count == 1 ? "" : "s")"
                accessibilityManager.announceMessage(announcement)
            }
        }
        }
        .sheet(isPresented: $isShowingAddFilesSheet) {
            AddFilesToPlaylistView()
                .environmentObject(playlistManager)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
            Spacer()
            
            VStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                Text("Build a Playlist")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .visualAccessibility()
                
                Text("Add imported files to create your custom playlist")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AccessibleSpacing.expanded(for: dynamicTypeSize))
                    .visualAccessibility(foreground: .secondary)
            }
            
            Button(action: {
                isShowingAddFilesSheet = true
            }) {
                HStack(spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                    Image(systemName: "plus.circle.fill")
                        .accessibilityHidden(true)
                    Text("Add Files")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, AccessibleSpacing.expanded(for: dynamicTypeSize))
                .padding(.vertical, AccessibleSpacing.standard(for: dynamicTypeSize))
                .background(
                    accessibilityManager.highContrastColor(base: .blue, highContrast: .primary)
                )
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .accessibilityLabel("Add files to playlist")
            .accessibilityHint("Double tap to open file selection and add audio files to your playlist")
            .accessibilityAddTraits(.isButton)
            
            Spacer()
        }
        .padding(AccessibleSpacing.expanded(for: dynamicTypeSize))
    }
    
    // MARK: - Playlist Content View
    
    private var playlistContentView: some View {
        VStack(alignment: .leading, spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
            // Playlist stats
            playlistStatsView
            
            // Playlist items list
            if let playlist = playlistManager.currentPlaylist {
                List {
                    ForEach(playlist.orderedItems, id: \.id) { playlistItem in
                        PlaylistItemRow(
                            playlistItem: playlistItem,
                            onPlay: {
                                if let audioFile = playlistItem.audioFile,
                                   let playlist = playlistManager.currentPlaylist {
                                    audioPlayerService.playFromPlaylist(audioFile, playlist: playlist, context: viewContext)
                                }
                            }
                        )
                    }
                    .onMove(perform: { source, destination in
                        playlistManager.movePlaylistItem(from: source, to: destination)
                        // Announce the move action for VoiceOver users
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            accessibilityManager.announceMessage("Track moved in playlist")
                        }
                    })
                    .onDelete { indexSet in
                        let currentItems = playlist.orderedItems
                        var deletedFileNames: [String] = []
                        for index in indexSet {
                            if index < currentItems.count {
                                let item = currentItems[index]
                                let fileName = item.audioFile?.fileNameWithoutExtension ?? "Unknown file"
                                deletedFileNames.append(fileName)
                                playlistManager.removePlaylistItem(item)
                            }
                        }
                        
                        // Announce deletion for VoiceOver users
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let announcement = deletedFileNames.count == 1 ? 
                                "Removed \(deletedFileNames.first!) from playlist" :
                                "Removed \(deletedFileNames.count) tracks from playlist"
                            accessibilityManager.announceMessage(announcement)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .padding(.horizontal, AccessibleSpacing.standard(for: dynamicTypeSize))
    }
    
    // MARK: - Playlist Stats View
    
    private var playlistStatsView: some View {
        HStack {
            VStack(alignment: .leading, spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                Text("\(playlistManager.getPlaylistCount()) tracks")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .visualAccessibility()
                    .accessibilityLabel(playlistStatsAccessibilityLabel)
                
                Text(TimeInterval(playlistManager.getPlaylistDuration()).formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .visualAccessibility(foreground: .secondary)
                    .accessibilityLabel("Total duration: \(TimeInterval(playlistManager.getPlaylistDuration()).accessibleDuration)")
            }
            
            Spacer()
            
            Button("Add Files") {
                isShowingAddFilesSheet = true
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Add more files to playlist")
            .accessibilityHint("Double tap to add additional audio files to the current playlist")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
    }
    
    // MARK: - Accessibility Computed Properties
    
    private var playlistStatsAccessibilityLabel: String {
        let count = playlistManager.getPlaylistCount()
        return "\(count) track\(count == 1 ? "" : "s") in playlist"
    }
}

// MARK: - Playlist Item Row

struct PlaylistItemRow: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    let playlistItem: PlaylistItem
    let onPlay: () -> Void
    
    private var isCurrentlyPlaying: Bool {
        guard let audioFile = playlistItem.audioFile else { return false }
        return audioPlayerService.currentAudioFile == audioFile
    }
    
    var body: some View {
        HStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            // Artwork thumbnail
            LocalAsyncImageWithPhase(url: playlistItem.audioFile?.artworkURL) { phase in
                switch phase {
                case .success(let image):
                    return AnyView(image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8)))
                case .failure(_):
                    return AnyView(RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                        ))
                case .empty:
                    return AnyView(RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        ))
                }
            }
            
            // Track info
            VStack(alignment: .leading, spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                Text(playlistItem.audioFile?.fileNameWithoutExtension ?? "Unknown File")
                    .font(.headline)
                    .foregroundColor(isCurrentlyPlaying ? .primary : .primary)
                    .lineLimit(1)
                    .visualAccessibility()
                
                Text(playlistItem.audioFile?.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .visualAccessibility(foreground: .secondary)
                
                // Original filename display
                if let fileName = playlistItem.audioFile?.fileName {
                    Text(fileName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .opacity(0.6)
                        .visualAccessibility(foreground: .secondary)
                }
                
                if let duration = playlistItem.audioFile?.duration {
                    Text(TimeInterval(duration).formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .visualAccessibility(foreground: .secondary)
                }
            }
            
            Spacer()
            
            // Play/pause button
            Button(action: onPlay) {
                Image(systemName: isCurrentlyPlaying && audioPlayerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(accessibilityManager.highContrastColor(base: .blue, highContrast: .primary))
            }
            .accessibilityLabel(playButtonAccessibilityLabel)
            .accessibilityHint(playButtonAccessibilityHint)
            .accessibilityAddTraits(.isButton)
        }
        .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(playlistItemAccessibilityLabel)
        .accessibilityHint(playlistItemAccessibilityHint)
        .accessibilityValue(playlistItemAccessibilityValue)
        .accessibilityAddTraits(isCurrentlyPlaying ? [.isButton, .isSelected] : .isButton)
    }
    
    // MARK: - Accessibility Computed Properties
    
    private var playlistItemAccessibilityLabel: String {
        let fileName = playlistItem.audioFile?.fileNameWithoutExtension ?? "Unknown File"
        let artist = playlistItem.audioFile?.artist ?? "Unknown Artist"
        let order = Int(playlistItem.order) + 1 // Convert to 1-based index for users
        let position = "Track \(order)"
        let status = isCurrentlyPlaying ? (audioPlayerService.isPlaying ? ", currently playing" : ", currently selected") : ""
        return "\(position): \(fileName) by \(artist)\(status)"
    }
    
    private var playlistItemAccessibilityHint: String {
        if isCurrentlyPlaying {
            return "Double tap to go to player. Swipe up or down with one finger to reorder. Swipe right to delete."
        } else {
            return "Double tap to play this track. Swipe up or down with one finger to reorder. Swipe right to delete."
        }
    }
    
    private var playlistItemAccessibilityValue: String {
        var components: [String] = []
        
        // Add duration if available
        if let duration = playlistItem.audioFile?.duration, duration > 0 {
            components.append("Duration: \(TimeInterval(duration).accessibleDuration)")
        }
        
        // Add playing status
        if isCurrentlyPlaying {
            let status = audioPlayerService.isPlaying ? "Playing" : "Paused"
            components.append(status)
        }
        
        return components.joined(separator: ". ")
    }
    
    private var playButtonAccessibilityLabel: String {
        if isCurrentlyPlaying && audioPlayerService.isPlaying {
            return "Pause track"
        } else if isCurrentlyPlaying {
            return "Resume track"
        } else {
            return "Play track"
        }
    }
    
    private var playButtonAccessibilityHint: String {
        if isCurrentlyPlaying && audioPlayerService.isPlaying {
            return "Double tap to pause this track"
        } else if isCurrentlyPlaying {
            return "Double tap to resume this track"
        } else {
            return "Double tap to play this track"
        }
    }
}

#Preview {
    PlaylistView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(PlaylistManager(context: PersistenceController.preview.container.viewContext))
        .environmentObject(AudioPlayerService())
        .environmentObject(AccessibilityManager())
}