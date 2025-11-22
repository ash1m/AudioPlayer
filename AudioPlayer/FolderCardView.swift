//
//  FolderCardView.swift
//  FireVox
//
//  Created by Assistant on 2025/09/22.
//

import SwiftUI
import CoreData

struct FolderGridCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var audioFileManager: AudioFileManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    let folder: Folder
    let artworkSize: CGFloat
    let action: () -> Void
    let onDelete: (Folder) -> Void
    let onSetCustomArtwork: (Folder) -> Void
    let onRemoveCustomArtwork: (Folder) -> Void
    
    var body: some View {
        Button(action: {
            playFolderAsPlaylist()
        }) {
            VStack(spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                // Artwork container styled like audio files
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [
                                accessibilityManager.highContrastColor(base: .green.opacity(0.2), highContrast: .black.opacity(0.4)),
                                accessibilityManager.highContrastColor(base: .blue.opacity(0.2), highContrast: .black.opacity(0.6))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: artworkSize, height: artworkSize)
                    
                    // Custom artwork or default icon
                    if let artworkURL = folder.artworkURL {
                        LocalAsyncImageWithPhase(url: artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                return AnyView(image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: artworkSize, height: artworkSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 16)))
                            case .failure(let error):
                                let _ = print("🎨 LocalAsyncImage failed to load folder artwork for \(folder.name): \(error)")
                                let _ = print("🎨 Folder artwork URL: \(artworkURL.path)")
                                let _ = print("🎨 File exists: \(FileManager.default.fileExists(atPath: artworkURL.path))")
                                return AnyView(Image(systemName: "play.rectangle.fill")
                                    .font(FontManager.font(.regular, size: artworkSize * 0.4))
                                    .foregroundColor(.white)
                                    .frame(width: artworkSize, height: artworkSize)
                                    .accessibilityHidden(true))
                            case .empty:
                                return AnyView(ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                    .frame(width: artworkSize, height: artworkSize))
                            }
                        }
                    } else {
                        // Default folder/playlist icon
                        Image(systemName: "play.rectangle.fill")
                            .font(FontManager.font(.regular, size: artworkSize * 0.4))
                            .foregroundColor(.white)
                            .frame(width: artworkSize, height: artworkSize)
                            .accessibilityHidden(true)
                    }
                    
                    // File count badge in top right corner
                    if folder.fileCount > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Text("\(folder.fileCount)")
                                    .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 12))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.8))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                            Spacer()
                        }
                        .frame(width: artworkSize, height: artworkSize)
                    }
                    
                    // Duration overlay (total duration of all files)
                    if totalDuration > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(TimeInterval(totalDuration).formattedDuration)
                                    .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 12))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.8))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                        }
                        .frame(width: artworkSize, height: artworkSize)
                    }
                    
                }
                
                // Progress bar for folders with playback state (outside the artwork area)
                if folder.hasPlaybackState && folder.playbackProgress > 0 {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.secondary.opacity(0.3))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(.blue)
                            .frame(width: artworkSize * folder.playbackProgress, height: 4)
                    }
                    .frame(width: artworkSize)
                    .clipShape(Capsule())
                }
                
                // Text content area styled like audio file
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(FontManager.fontWithSystemFallback(weight: .medium, size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .visualAccessibility()
                    
                    Text("\(folder.fileCount) track\(folder.fileCount == 1 ? "" : "s")")
                        .font(FontManager.font(.regular, size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .visualAccessibility(foreground: .secondary)
                }
                .padding(.horizontal, AccessibleSpacing.compact(for: dynamicTypeSize))
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Custom artwork actions
            Button(action: {
                onSetCustomArtwork(folder)
            }) {
                Label("Set Custom Artwork", systemImage: "photo")
            }
            .accessibilityLabel("Set custom artwork")
            .accessibilityHint("Choose a custom image as folder artwork")
            
            if audioFileManager.hasCustomArtwork(for: folder) {
                Button(action: {
                    onRemoveCustomArtwork(folder)
                }) {
                    Label("Remove Custom Artwork", systemImage: "trash")
                }
                .accessibilityLabel("Remove custom artwork")
                .accessibilityHint("Remove the custom artwork and revert to default")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                onDelete(folder)
            }) {
                Label("Delete Folder", systemImage: "trash")
            }
        }
        .accessibilityLabel(folderAccessibilityLabel)
        .accessibilityHint(folderAccessibilityHint)
        .accessibilityValue(folderAccessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibleTouchTarget()
        .visualAccessibility(reducedMotion: true)
    }
    
    // MARK: - Computed Properties
    
    private var totalDuration: Double {
        return folder.audioFilesArray.reduce(0) { total, audioFile in
            total + audioFile.duration
        }
    }
    
    // MARK: - Playlist Functionality
    
    private func playFolderAsPlaylist() {
        let audioFiles = folder.audioFilesArray
        guard !audioFiles.isEmpty else { return }
        
        // Use the new folder playback functionality instead of playlist
        audioPlayerService.playFromFolder(folder, resumeFromSavedState: true, context: viewContext)
    }
    
    // MARK: - Computed Properties for Accessibility
    
    private var folderAccessibilityLabel: String {
        return "Audio series: \(folder.name)"
    }
    
    private var folderAccessibilityHint: String {
        if folder.hasPlaybackState {
            return "Double tap to resume playback from where you left off"
        } else {
            return "Double tap to play all tracks in sequence"
        }
    }
    
    private var folderAccessibilityValue: String {
        let trackCountText = folder.fileCount == 1 ? "1 track" : "\(folder.fileCount) tracks"
        let durationText = totalDuration > 0 ? ", Total duration: \(TimeInterval(totalDuration).accessibleDuration)" : ""
        let progressText = folder.hasPlaybackState ? ", \(Int(folder.playbackProgress * 100))% complete" : ""
        return "\(trackCountText)\(durationText)\(progressText)"
    }
    
}

struct FolderListCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var audioFileManager: AudioFileManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    let folder: Folder
    let action: () -> Void
    let onDelete: (Folder) -> Void
    let onSetCustomArtwork: (Folder) -> Void
    let onRemoveCustomArtwork: (Folder) -> Void
    
    var body: some View {
        Button(action: {
            playFolderAsPlaylist()
        }) {
            HStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
                folderIconView
                folderContentView
                chevronView
            }
            .frame(height: 80)
            .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
            .padding(.horizontal, 12)
            .background(backgroundView)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Custom artwork actions
            Button(action: {
                onSetCustomArtwork(folder)
            }) {
                Label("Set Custom Artwork", systemImage: "photo")
            }
            .accessibilityLabel("Set custom artwork")
            .accessibilityHint("Choose a custom image as folder artwork")
            
            if audioFileManager.hasCustomArtwork(for: folder) {
                Button(action: {
                    onRemoveCustomArtwork(folder)
                }) {
                    Label("Remove Custom Artwork", systemImage: "trash")
                }
                .accessibilityLabel("Remove custom artwork")
                .accessibilityHint("Remove the custom artwork and revert to default")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                onDelete(folder)
            }) {
                Label("Delete Folder", systemImage: "trash")
            }
        }
        .accessibilityLabel(folderAccessibilityLabel)
        .accessibilityHint(folderAccessibilityHint)
        .accessibilityValue(folderAccessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibleTouchTarget()
        .visualAccessibility(reducedMotion: true)
    }
    
    // MARK: - Computed Properties
    
    private var totalDuration: Double {
        return folder.audioFilesArray.reduce(0) { total, audioFile in
            total + audioFile.duration
        }
    }
    
    // MARK: - Playlist Functionality
    
    private func playFolderAsPlaylist() {
        let audioFiles = folder.audioFilesArray
        guard !audioFiles.isEmpty else { return }
        
        // Use the new folder playback functionality instead of playlist
        audioPlayerService.playFromFolder(folder, resumeFromSavedState: true, context: viewContext)
    }
    
    // MARK: - Computed Properties for Accessibility
    
    private var folderAccessibilityLabel: String {
        return "Audio series: \(folder.name)"
    }
    
    private var folderAccessibilityHint: String {
        if folder.hasPlaybackState {
            return "Double tap to resume playback from where you left off"
        } else {
            return "Double tap to play all tracks in sequence"
        }
    }
    
    private var folderAccessibilityValue: String {
        let trackCountText = folder.fileCount == 1 ? "1 track" : "\(folder.fileCount) tracks"
        let durationText = totalDuration > 0 ? ", Total duration: \(TimeInterval(totalDuration).accessibleDuration)" : ""
        let progressText = folder.hasPlaybackState ? ", \(Int(folder.playbackProgress * 100))% complete" : ""
        return "\(trackCountText)\(durationText)\(progressText)"
    }
    
    // MARK: - Component Views
    
    private var folderIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [
                        accessibilityManager.highContrastColor(base: .green.opacity(0.3), highContrast: .black.opacity(0.5)),
                        accessibilityManager.highContrastColor(base: .blue.opacity(0.3), highContrast: .black.opacity(0.7))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)
            
            // Custom artwork or default icon
            if let artworkURL = folder.artworkURL {
                LocalAsyncImageWithPhase(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        return AnyView(image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8)))
                    case .failure(let error):
                        let _ = print("🎨 LocalAsyncImage failed to load folder artwork for \(folder.name): \(error)")
                        return AnyView(Image(systemName: "play.rectangle.fill")
                            .font(FontManager.font(.regular, size: 22))
                            .foregroundColor(.white))
                    case .empty:
                        return AnyView(ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8))
                    }
                }
            } else {
                Image(systemName: "play.rectangle.fill")
                    .font(FontManager.font(.regular, size: 22))
                    .foregroundColor(.white)
            }
            
            // File count badge
            if folder.fileCount > 0 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(folder.fileCount)")
                            .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .frame(width: 60, height: 60)
                .padding(4)
            }
        }
    }
    
    private var folderContentView: some View {
        VStack(alignment: .leading, spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
            Text(folder.name)
                .dynamicTypeSupport(.headline, maxSize: .accessibility2, lineLimit: 2, allowsTightening: true)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .visualAccessibility()
            
            Text("\(folder.fileCount) track\(folder.fileCount == 1 ? "" : "s")")
                .dynamicTypeSupport(.caption, maxSize: .accessibility1, lineLimit: 1)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .visualAccessibility(foreground: .secondary)
            
            // Show progress bar if folder has playback state
            if folder.hasPlaybackState && folder.playbackProgress > 0 {
                ProgressView(value: folder.playbackProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .background(Color.secondary.opacity(0.3))
                    .clipShape(Capsule())
                    .frame(height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Show folder path if it's not root
            if folder.path != "/" && !folder.path.isEmpty {
                Text(folder.path)
                    .font(FontManager.font(.regular, size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var chevronView: some View {
        Image(systemName: "chevron.right")
            .font(FontManager.font(.regular, size: 12))
            .foregroundColor(.secondary)
            .padding(.trailing, 4)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleFolder = Folder(context: context, name: "Sample Folder", path: "/sample")
    sampleFolder.fileCount = 5
    
    return VStack {
        FolderGridCard(
            folder: sampleFolder,
            artworkSize: 120,
            action: {},
            onDelete: { _ in },
            onSetCustomArtwork: { _ in },
            onRemoveCustomArtwork: { _ in }
        )
        
        FolderListCard(
            folder: sampleFolder,
            action: {},
            onDelete: { _ in },
            onSetCustomArtwork: { _ in },
            onRemoveCustomArtwork: { _ in }
        )
    }
    .environmentObject(AccessibilityManager())
    .padding()
}
