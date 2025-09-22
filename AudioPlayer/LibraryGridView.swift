//
//  LibraryGridView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/16.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

enum LibraryViewMode: CaseIterable {
    case grid
    case list
    
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .grid: return "Grid view"
        case .list: return "List view"
        }
    }
}

struct LibraryGridView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var audioFileManager: AudioFileManager
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    let navigateToPlayer: () -> Void
    
    @StateObject private var folderNavigationManager = FolderNavigationManager()
    @State private var folders: [Folder] = []
    @State private var audioFiles: [AudioFile] = []
    @State private var refreshTrigger = UUID()
    
    @State private var isShowingDocumentPicker = false
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isImporting = false
    @State private var importResults: [AudioFileManager.ImportResult] = []
    @State private var isShowingDetailedResults = false
    @State private var viewMode: LibraryViewMode = .grid
    
    private var gridColumns: [GridItem] {
        let spacing = AccessibleSpacing.standard(for: dynamicTypeSize)
        
        // Two equal flexible columns for large card display
        return [
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing)
        ]
    }
    
    // Consistent artwork size for all cards
    private var artworkSize: CGFloat {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return 160 // Large artwork for accessibility
        case .xLarge, .xxLarge, .xxxLarge:
            return 140 // Medium-large artwork
        case .large:
            return 120 // Standard large artwork
        default:
            return 100 // Standard artwork
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with toggle
                HStack {
                    // View mode toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = viewMode == .grid ? .list : .grid
                        }
                    }) {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel(viewMode == .grid ? "Switch to list view" : "Switch to grid view")
                    .accessibilityHint("Double tap to change the view mode")
                    
                    Spacer()
                    
                    // Import button
                    Button(action: {
                        isShowingDocumentPicker = true
                    }) {
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .accessibilityLabel(isImporting ? "Importing files" : "Import audio files")
                    .accessibilityHint(isImporting ? "Files are being imported" : "Double tap to select audio files to import")
                    .disabled(isImporting)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Breadcrumb navigation
                if folderNavigationManager.canNavigateBack {
                    BreadcrumbNavigation(folderNavigationManager: folderNavigationManager)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                
                // Main content
                if folders.isEmpty && audioFiles.isEmpty {
                    ContentUnavailableView(
                        folderNavigationManager.isInFolder ? "Empty Folder" : "No Content",
                        systemImage: folderNavigationManager.isInFolder ? "folder" : "music.note.list",
                        description: Text(folderNavigationManager.isInFolder ? "This folder is empty" : "Tap the + button to import audio files or folders")
                    )
                    .accessibilityLabel(folderNavigationManager.isInFolder ? "Folder is empty" : "Library is empty")
                    .accessibilityHint("Import audio files using the add button")
                    .dynamicContentFocus(
                        description: "Library content", 
                        hasContent: false, 
                        emptyMessage: folderNavigationManager.isInFolder ? "No content in this folder" : "No audio files in library. Use the import button to add files."
                    )
                } else {
                    ScrollView {
                        if viewMode == .grid {
                            LazyVGrid(columns: gridColumns, spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
                                // Show folders first
                                ForEach(folders, id: \.self) { folder in
                                    FolderGridCard(
                                        folder: folder,
                                        artworkSize: artworkSize,
                                        action: { handleFolderSelection(folder) },
                                        onDelete: { folder in
                                            folderNavigationManager.deleteFolder(folder, context: viewContext)
                                            refreshContent()
                                        }
                                    )
                                }
                                
                                // Then show audio files
                                ForEach(audioFiles, id: \.self) { audioFile in
                                    AudioFileGridCard(
                                        audioFile: audioFile,
                                        artworkSize: artworkSize,
                                        action: { handleAudioFileSelection(audioFile) },
                                        onDelete: deleteAudioFile,
                                        onMarkAsPlayed: markAsPlayed,
                                        onResetProgress: resetProgress,
                                        onShare: shareAudioFile
                                    )
                                }
                            }
                            .animation(.none, value: audioFiles.count) // Prevent layout animations on async content changes
                            .animation(.none, value: folders.count)
                            .accessiblePadding(.horizontal, dynamicTypeSize: dynamicTypeSize)
                            .accessiblePadding(.top, dynamicTypeSize: dynamicTypeSize)
                        } else {
                            LazyVStack(spacing: 0) {
                                // Show folders first in list mode
                                ForEach(folders, id: \.self) { folder in
                                    VStack(spacing: 0) {
                                        FolderListCard(
                                            folder: folder,
                                            action: { handleFolderSelection(folder) },
                                            onDelete: { folder in
                                                folderNavigationManager.deleteFolder(folder, context: viewContext)
                                                refreshContent()
                                            }
                                        )
                                        
                                        if folder != folders.last || !audioFiles.isEmpty {
                                            Divider()
                                                .padding(.leading, 76)
                                        }
                                    }
                                }
                                
                                // Then show audio files
                                ForEach(audioFiles, id: \.self) { audioFile in
                                    VStack(spacing: 0) {
                                        AudioFileListCard(
                                            audioFile: audioFile,
                                            action: { handleAudioFileSelection(audioFile) },
                                            onDelete: deleteAudioFile,
                                            onMarkAsPlayed: markAsPlayed,
                                            onResetProgress: resetProgress,
                                            onShare: shareAudioFile
                                        )
                                        
                                        if audioFile != audioFiles.last {
                                            Divider()
                                                .padding(.leading, 76)
                                        }
                                    }
                                }
                            }
                            .accessiblePadding(.horizontal, dynamicTypeSize: dynamicTypeSize)
                            .accessiblePadding(.top, dynamicTypeSize: dynamicTypeSize)
                        }
                    }
                }
            }
        }
        .navigationTitle(folderNavigationManager.isInFolder ? folderNavigationManager.currentFolder?.name ?? "Folder" : "Library")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityLabel(libraryAccessibilityLabel)
        .dynamicContentFocus(
            description: folderNavigationManager.currentLocationDescription, 
            hasContent: !folders.isEmpty || !audioFiles.isEmpty, 
            emptyMessage: folderNavigationManager.isInFolder ? "No content in this folder" : "No audio files in library"
        )
        .onAppear {
            loadCurrentContent()
        }
        .onChange(of: folderNavigationManager.currentFolder) { _ in
            loadCurrentContent()
        }
        .onChange(of: refreshTrigger) { _ in
            loadCurrentContent()
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPicker(
                allowedContentTypes: [
                    .mp3,
                    .mpeg4Audio,
                    .wav,
                    .audio
                ]
            ) { urls in
                importAudioFiles(urls: urls)
            }
            .modalFocus(title: "File picker", isPresented: isShowingDocumentPicker)
        }
        .alert("Import Results", isPresented: $isShowingAlert) {
            Button("OK") { }
            if importResults.contains(where: { !$0.success }) {
                Button("View Details") {
                    isShowingDetailedResults = true
                }
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $isShowingDetailedResults) {
            ImportResultsDetailView(results: importResults)
        }
    }
    
    
    private func handleAudioFileSelection(_ audioFile: AudioFile) {
        // Check if this is the currently playing file
        if audioPlayerService.currentAudioFile == audioFile {
            // Same file - just navigate to player without restarting
            navigateToPlayer()
        } else {
            // Different file - load and play new audio
            audioPlayerService.loadAudioFile(audioFile, context: viewContext)
            // Start playback automatically
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                audioPlayerService.play()
            }
            // Navigate to player tab
            navigateToPlayer()
        }
    }
    
    private func deleteAudioFile(_ audioFile: AudioFile) {
        // Stop playback if this file is currently playing
        if audioPlayerService.currentAudioFile == audioFile {
            audioPlayerService.stop()
        }
        
        // Delete the actual audio file
        if let fileURL = audioFile.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Delete artwork if it exists
        if let artworkURL = audioFile.artworkURL {
            try? FileManager.default.removeItem(at: artworkURL)
        }
        
        // Delete from Core Data
        viewContext.delete(audioFile)
        
        // Save the context
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete audio file: \(error)")
        }
    }
    
    private func markAsPlayed(_ audioFile: AudioFile) {
        // Set current position to the end of the track
        audioFile.currentPosition = audioFile.duration
        
        // Save the context
        do {
            try viewContext.save()
        } catch {
            print("Failed to mark audio file as played: \(error)")
        }
    }
    
    private func resetProgress(_ audioFile: AudioFile) {
        // Reset current position to the beginning
        audioFile.currentPosition = 0
        
        // If this file is currently playing, seek to the beginning
        if audioPlayerService.currentAudioFile == audioFile {
            audioPlayerService.seek(to: 0)
        }
        
        // Save the context
        do {
            try viewContext.save()
        } catch {
            print("Failed to reset progress: \(error)")
        }
    }
    
    private func shareAudioFile(_ audioFile: AudioFile) {
        guard let fileURL = audioFile.fileURL else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // Get the current window scene and present the share sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // For iPad, set the source rect/view
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityViewController.popoverPresentationController?.sourceView = rootViewController.view
            activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
    
    private func importAudioFiles(urls: [URL]) {
        isImporting = true
        
        Task {
            let results = await audioFileManager.importAudioFiles(urls: urls, context: viewContext)
            
            await MainActor.run {
                isImporting = false
                importResults = results
                
                let successCount = results.filter { $0.success }.count
                let failureCount = results.count - successCount
                let totalProcessed = results.count
                
                if failureCount == 0 {
                    if totalProcessed == 1 {
                        alertMessage = "Successfully imported 1 file!"
                    } else {
                        alertMessage = "Successfully imported \(successCount) files!"
                    }
                } else if successCount == 0 {
                    alertMessage = "Failed to import \(failureCount) file(s). Tap 'View Details' for more information."
                } else {
                    alertMessage = "Imported \(successCount) file(s) successfully.\n\(failureCount) file(s) failed to import. Tap 'View Details' for more information."
                }
                
                isShowingAlert = true
                
                // Announce import results for VoiceOver users
                accessibilityManager.announceLibraryUpdate(
                    importedCount: successCount, 
                    totalLibraryCount: audioFiles.count
                )
                
                // Reload content after import
                loadCurrentContent()
            }
        }
    }
    
    // MARK: - Folder Navigation Methods
    
    private func handleFolderSelection(_ folder: Folder) {
        folderNavigationManager.navigateToFolder(folder)
        
        // Announce folder navigation for VoiceOver
        let subfolderCount = folder.subFoldersArray.count
        let fileCount = folder.audioFilesArray.count
        accessibilityManager.announceFolderNavigation(
            folderName: folder.name,
            fileCount: fileCount,
            subfolderCount: subfolderCount
        )
    }
    
    private func loadCurrentContent() {
        folders = folderNavigationManager.getFolders(context: viewContext)
        audioFiles = folderNavigationManager.getAudioFiles(context: viewContext)
    }
    
    private func refreshContent() {
        // Trigger a UI refresh by updating the refresh trigger
        refreshTrigger = UUID()
        // Also reload the content immediately
        loadCurrentContent()
    }
    
    private var libraryAccessibilityLabel: String {
        let folderCount = folders.count
        let fileCount = audioFiles.count
        let totalItems = folderCount + fileCount
        
        if folderNavigationManager.isInFolder {
            if totalItems == 0 {
                return "Empty folder"
            } else {
                var description = "Folder with "
                if folderCount > 0 {
                    description += "\(folderCount) folder\(folderCount == 1 ? "" : "s")"
                    if fileCount > 0 {
                        description += " and "
                    }
                }
                if fileCount > 0 {
                    description += "\(fileCount) file\(fileCount == 1 ? "" : "s")"
                }
                return description
            }
        } else {
            if totalItems == 0 {
                return "Empty library"
            } else {
                var description = "Audio library with "
                if folderCount > 0 {
                    description += "\(folderCount) folder\(folderCount == 1 ? "" : "s")"
                    if fileCount > 0 {
                        description += " and "
                    }
                }
                if fileCount > 0 {
                    description += "\(fileCount) file\(fileCount == 1 ? "" : "s")"
                }
                return description
            }
        }
    }
}

struct AudioFileGridCard: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.managedObjectContext) private var viewContext
    let audioFile: AudioFile
    let artworkSize: CGFloat
    let action: () -> Void
    let onDelete: (AudioFile) -> Void
    let onMarkAsPlayed: (AudioFile) -> Void
    let onResetProgress: (AudioFile) -> Void
    let onShare: (AudioFile) -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                // Large artwork container with consistent size
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [
                                accessibilityManager.highContrastColor(base: .blue.opacity(0.2), highContrast: .gray.opacity(0.4)),
                                accessibilityManager.highContrastColor(base: .purple.opacity(0.2), highContrast: .gray.opacity(0.6))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: artworkSize, height: artworkSize)
                    
                    // Artwork content
                    if let artworkURL = audioFile.artworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: artworkSize, height: artworkSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            case .failure(_):
                                Image(systemName: "music.note")
                                    .font(.system(size: artworkSize * 0.4))
                                    .foregroundColor(.white)
                                    .frame(width: artworkSize, height: artworkSize)
                            case .empty:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                    .frame(width: artworkSize, height: artworkSize)
                            @unknown default:
                                Image(systemName: "music.note")
                                    .font(.system(size: artworkSize * 0.4))
                                    .foregroundColor(.white)
                                    .frame(width: artworkSize, height: artworkSize)
                            }
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: artworkSize * 0.4))
                            .foregroundColor(.white)
                            .frame(width: artworkSize, height: artworkSize)
                    }
                    
                    // Play/Pause indicator overlay
                    if audioPlayerService.currentAudioFile == audioFile {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: audioPlayerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.black.opacity(0.8)))
                                    .padding(8)
                            }
                            Spacer()
                        }
                        .frame(width: artworkSize, height: artworkSize)
                    }
                    
                    // Duration overlay
                    if audioFile.duration > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(TimeInterval(audioFile.duration).formattedDuration)
                                    .font(.caption)
                                    .fontWeight(.semibold)
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
                
                // Progress bar directly under artwork
                if audioFile.duration > 0 {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.secondary.opacity(0.3))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(.blue)
                            .frame(width: artworkSize * progressPercentage, height: 4)
                    }
                    .frame(width: artworkSize)
                    .clipShape(Capsule())
                }
                
                // Text content area with improved typography
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioFile.title ?? "Unknown Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .visualAccessibility()
                    
                    Text(audioFile.artist ?? "Unknown Artist")
                        .font(.caption)
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
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Playback actions
            Button(action: {
                onMarkAsPlayed(audioFile)
            }) {
                Label("Mark as Played", systemImage: "checkmark.circle")
            }
            
            Button(action: {
                onResetProgress(audioFile)
            }) {
                Label("Reset Progress", systemImage: "arrow.counterclockwise")
            }
            
            Divider()
            
            // Sharing action
            Button(action: {
                onShare(audioFile)
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            // Destructive action
            Button(role: .destructive, action: {
                onDelete(audioFile)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel(audioAccessibilityLabel)
        .accessibilityHint(audioAccessibilityHint)
        .accessibilityValue(audioAccessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibleTouchTarget()
        .visualAccessibility(reducedMotion: true)
    }
    
    // MARK: - Computed Properties
    
    private var progressPercentage: Double {
        guard audioFile.duration > 0 else { return 0 }
        
        // If this is the currently playing file, use the live current time
        if audioPlayerService.currentAudioFile == audioFile {
            return min(max(audioPlayerService.currentTime / audioFile.duration, 0), 1)
        } else {
            // Use the saved position for non-playing files
            return min(max(audioFile.currentPosition / audioFile.duration, 0), 1)
        }
    }
    
    // MARK: - Computed Properties for Accessibility
    
    private var audioAccessibilityLabel: String {
        let title = audioFile.title ?? "Unknown Title"
        let artist = audioFile.artist ?? "Unknown Artist"
        let isCurrentlyPlaying = audioPlayerService.currentAudioFile == audioFile
        let playbackStatus = isCurrentlyPlaying ? (audioPlayerService.isPlaying ? "Currently playing" : "Currently paused") : ""
        
        return "\(title) by \(artist). \(playbackStatus)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var audioAccessibilityHint: String {
        let isCurrentlyPlaying = audioPlayerService.currentAudioFile == audioFile
        return isCurrentlyPlaying ? "Double tap to go to player" : "Double tap to play"
    }
    
    private var audioAccessibilityValue: String {
        let duration = TimeInterval(audioFile.duration).accessibleDuration
        let isCurrentlyPlaying = audioPlayerService.currentAudioFile == audioFile
        
        // Include progress information
        let progress = Int(progressPercentage * 100)
        let progressText = progress > 0 ? ". \(progress)% played" : ""
        
        return isCurrentlyPlaying ? "Duration: \(duration). Currently selected\(progressText)." : "Duration: \(duration)\(progressText)"
    }
}

struct AudioFileListCard: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.managedObjectContext) private var viewContext
    let audioFile: AudioFile
    let action: () -> Void
    let onDelete: (AudioFile) -> Void
    let onMarkAsPlayed: (AudioFile) -> Void
    let onResetProgress: (AudioFile) -> Void
    let onShare: (AudioFile) -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
                // Thumbnail and progress column
                VStack(spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                    // Square thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [
                                    accessibilityManager.highContrastColor(base: .blue.opacity(0.3), highContrast: .gray.opacity(0.5)),
                                    accessibilityManager.highContrastColor(base: .purple.opacity(0.3), highContrast: .gray.opacity(0.7))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 60, height: 60)
                        
                        if let artworkURL = audioFile.artworkURL {
                            AsyncImage(url: artworkURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure(_):
                                    Image(systemName: "music.note")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                case .empty:
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.6)
                                @unknown default:
                                    Image(systemName: "music.note")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        // Play/Pause indicator for currently playing file
                        if audioPlayerService.currentAudioFile == audioFile {
                            VStack {
                                HStack {
                                    Spacer()
                                    Image(systemName: audioPlayerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(.black.opacity(0.7)).frame(width: 16, height: 16))
                                }
                                Spacer()
                            }
                            .frame(width: 60, height: 60)
                            .padding(4)
                        }
                    }
                    
                    // Progress bar under thumbnail
                    if audioFile.duration > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(.secondary.opacity(0.3))
                                    .frame(height: 2)
                                
                                Rectangle()
                                    .fill(.primary)
                                    .frame(width: geometry.size.width * progressPercentage, height: 2)
                            }
                            .clipShape(Capsule())
                        }
                        .frame(width: 60, height: 2)
                    }
                }
                
                // Title and metadata column
                VStack(alignment: .leading, spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                    Text(audioFile.title ?? "Unknown Title")
                        .dynamicTypeSupport(.headline, maxSize: .accessibility2, lineLimit: 2, allowsTightening: true)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .visualAccessibility()
                    
                    if let artist = audioFile.artist, !artist.isEmpty {
                        Text(artist)
                            .dynamicTypeSupport(.caption, maxSize: .accessibility1, lineLimit: 2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .visualAccessibility(foreground: .secondary)
                    } else {
                        Text("Unknown Artist")
                            .dynamicTypeSupport(.caption, maxSize: .accessibility1, lineLimit: 2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .visualAccessibility(foreground: .secondary)
                    }
                    
                    // Duration in bottom right
                    if audioFile.duration > 0 {
                        HStack {
                            Spacer()
                            Text(TimeInterval(audioFile.duration).formattedDuration)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 80)
            .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Playback actions
            Button(action: {
                onMarkAsPlayed(audioFile)
            }) {
                Label("Mark as Played", systemImage: "checkmark.circle")
            }
            
            Button(action: {
                onResetProgress(audioFile)
            }) {
                Label("Reset Progress", systemImage: "arrow.counterclockwise")
            }
            
            Divider()
            
            // Sharing action
            Button(action: {
                onShare(audioFile)
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            // Destructive action
            Button(role: .destructive, action: {
                onDelete(audioFile)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel(audioAccessibilityLabel)
        .accessibilityHint(audioAccessibilityHint)
        .accessibilityValue(audioAccessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibleTouchTarget()
        .visualAccessibility(reducedMotion: true)
    }
    
    // MARK: - Computed Properties
    
    private var progressPercentage: Double {
        guard audioFile.duration > 0 else { return 0 }
        
        // If this is the currently playing file, use the live current time
        if audioPlayerService.currentAudioFile == audioFile {
            return min(max(audioPlayerService.currentTime / audioFile.duration, 0), 1)
        } else {
            // Use the saved position for non-playing files
            return min(max(audioFile.currentPosition / audioFile.duration, 0), 1)
        }
    }
    
    // MARK: - Computed Properties for Accessibility
    
    private var audioAccessibilityLabel: String {
        let title = audioFile.title ?? "Unknown Title"
        let artist = audioFile.artist ?? "Unknown Artist"
        let isCurrentlyPlaying = audioPlayerService.currentAudioFile == audioFile
        let playbackStatus = isCurrentlyPlaying ? (audioPlayerService.isPlaying ? "Currently playing" : "Currently paused") : ""
        
        return "\(title) by \(artist). \(playbackStatus)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var audioAccessibilityHint: String {
        let isCurrentlyPlaying = audioPlayerService.currentAudioFile == audioFile
        return isCurrentlyPlaying ? "Double tap to go to player" : "Double tap to play"
    }
    
    private var audioAccessibilityValue: String {
        let duration = TimeInterval(audioFile.duration).accessibleDuration
        let isCurrentlyPlaying = audioPlayerService.currentAudioFile == audioFile
        
        // Include progress information
        let progress = Int(progressPercentage * 100)
        let progressText = progress > 0 ? ". \(progress)% played" : ""
        
        return isCurrentlyPlaying ? "Duration: \(duration). Currently selected\(progressText)." : "Duration: \(duration)\(progressText)"
    }
}

#Preview {
    LibraryGridView(navigateToPlayer: {})
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
        .environmentObject(AudioFileManager())
        .environmentObject(AccessibilityManager())
}
