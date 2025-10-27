//
//  LibraryGridView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/16.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import UIKit

enum LibraryViewMode: CaseIterable {
    case grid
    case list
}

enum SortOption: String, CaseIterable {
    case fileName = "File Name"
    case title = "Title"
    case artist = "Artist"
    case dateAdded = "Date Added"
    case duration = "Duration"
}

struct LibraryGridView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var audioFileManager: AudioFileManager
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var localizationManager: LocalizationManager
    
    let navigateToPlayer: () -> Void
    let navigateToSettings: () -> Void
    
    @StateObject private var folderNavigationManager = FolderNavigationManager()
    @State private var folders: [Folder] = []
    @State private var audioFiles: [AudioFile] = []
    @State private var refreshTrigger = UUID()
    
    @State private var isShowingDocumentPicker = false
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var showingImportResults = false
    @State private var importResults: [AudioFileManager.ImportResult] = []
    @State private var showingArtworkPicker = false
    @State private var selectedAudioFileForArtwork: AudioFile?
    @State private var selectedFolderForArtwork: Folder?
    @State private var artworkErrorMessage = ""
    @State private var isShowingDetailedResults = false
    @State private var isImporting = false
    @State private var viewMode: LibraryViewMode = .grid
    @State private var sortOption: SortOption = .fileName
    
    // Performance optimization - reduce view rebuilds
    @State private var lastContentRefresh: CFTimeInterval = 0
    @State private var isContentLoading = false
    
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
        VStack(spacing: 0) {
            headerView
            breadcrumbView
            contentView
        }
        .accessibilityLabel(libraryAccessibilityLabel)
        .dynamicContentFocus(
            description: folderNavigationManager.currentLocationDescription,
            hasContent: !folders.isEmpty || !audioFiles.isEmpty,
            emptyMessage: folderNavigationManager.isInFolder ? "No content in this folder" : "No audio files in library"
        )
        .onAppear {
            loadCurrentContent()
        }
        .onChange(of: folderNavigationManager.currentFolder) { _, _ in
            loadCurrentContent()
        }
        .onChange(of: refreshTrigger) { _, _ in
            loadCurrentContent()
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPicker(
                allowedContentTypes: [
                    .mp3,
                    .mpeg4Audio,
                    .wav,
                    .audio
                ],
                onDocumentsSelected: importAudioFiles
            )
        }
        .sheet(isPresented: $showingArtworkPicker) {
            if let selectedAudioFile = selectedAudioFileForArtwork {
                CustomArtworkPicker(
                    isPresented: $showingArtworkPicker,
                    onImageSelected: { image in
                        handleCustomArtwork(for: selectedAudioFile, image: image)
                    },
                    onError: { error in
                        artworkErrorMessage = error
                        isShowingAlert = true
                        alertMessage = artworkErrorMessage
                    }
                )
            } else if let selectedFolder = selectedFolderForArtwork {
                CustomArtworkPicker(
                    isPresented: $showingArtworkPicker,
                    onImageSelected: { image in
                        handleCustomArtwork(for: selectedFolder, image: image)
                    },
                    onError: { error in
                        artworkErrorMessage = error
                        isShowingAlert = true
                        alertMessage = artworkErrorMessage
                    }
                )
            }
        }
        .alert(localizationManager.importResultsTitle, isPresented: $isShowingAlert) {
            Button(localizationManager.importButtonOK) { }
            if importResults.contains(where: { !$0.success }) {
                Button(localizationManager.importButtonViewDetails) {
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
        
        // Update parent folder file count if file was in a folder
        if let parentFolder = audioFile.folder {
            parentFolder.updateFileCount()
        }
        
        // Save the context
        do {
            try viewContext.save()
            // Refresh the UI after successful deletion
            refreshContent()
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
    
    private func setCustomArtwork(_ audioFile: AudioFile) {
        selectedAudioFileForArtwork = audioFile
        selectedFolderForArtwork = nil // Clear folder selection
        showingArtworkPicker = true
    }
    
    private func handleCustomArtwork(for audioFile: AudioFile, image: UIImage) {
        guard let imageData = ArtworkValidator.processImageForArtwork(image) else {
            artworkErrorMessage = "Failed to process selected image"
            isShowingAlert = true
            alertMessage = artworkErrorMessage
            return
        }
        
        Task {
            do {
                try await audioFileManager.saveCustomArtwork(for: audioFile, imageData: imageData, context: viewContext)
                
                await MainActor.run {
                    // Trigger a refresh to update the UI
                    refreshContent()
                    
                    // Announce success for VoiceOver users
                    accessibilityManager.announceMessage("Custom artwork set for \(audioFile.title ?? "audio file")")
                }
                
            } catch {
                await MainActor.run {
                    artworkErrorMessage = "Failed to save custom artwork: \(error.localizedDescription)"
                    isShowingAlert = true
                    alertMessage = artworkErrorMessage
                }
            }
        }
    }
    
    private func removeCustomArtwork(_ audioFile: AudioFile) {
        Task {
            await audioFileManager.removeCustomArtwork(for: audioFile, context: viewContext)
            
            await MainActor.run {
                // Trigger a refresh to update the UI
                refreshContent()
                
                // Announce removal for VoiceOver users
                accessibilityManager.announceMessage("Custom artwork removed from \(audioFile.title ?? "audio file")")
            }
        }
    }
    
    // MARK: - Folder Artwork Methods
    
    private func setCustomArtwork(_ folder: Folder) {
        selectedFolderForArtwork = folder
        selectedAudioFileForArtwork = nil // Clear audio file selection
        showingArtworkPicker = true
    }
    
    private func handleCustomArtwork(for folder: Folder, image: UIImage) {
        guard let imageData = ArtworkValidator.processImageForArtwork(image) else {
            artworkErrorMessage = "Failed to process selected image"
            isShowingAlert = true
            alertMessage = artworkErrorMessage
            return
        }
        
        Task {
            do {
                try await audioFileManager.saveCustomArtwork(for: folder, imageData: imageData, context: viewContext)
                
                await MainActor.run {
                    // Trigger a refresh to update the UI
                    refreshContent()
                    
                    // Announce success for VoiceOver users
                    accessibilityManager.announceMessage("Custom artwork set for folder \(folder.name)")
                }
                
            } catch {
                await MainActor.run {
                    artworkErrorMessage = "Failed to save custom artwork: \(error.localizedDescription)"
                    isShowingAlert = true
                    alertMessage = artworkErrorMessage
                }
            }
        }
    }
    
    private func removeCustomArtwork(_ folder: Folder) {
        Task {
            await audioFileManager.removeCustomArtwork(for: folder, context: viewContext)
            
            await MainActor.run {
                // Trigger a refresh to update the UI
                refreshContent()
                
                // Announce removal for VoiceOver users
                accessibilityManager.announceMessage("Custom artwork removed from folder \(folder.name)")
            }
        }
    }
    
    private func importAudioFiles(urls: [URL]) {
        Task { @MainActor in
            isImporting = true
        }
        
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
                        alertMessage = localizationManager.importSuccessSingle
                    } else {
                        alertMessage = localizationManager.importSuccessMultiple(successCount)
                    }
                } else if successCount == 0 {
                    alertMessage = localizationManager.importFailureAll(failureCount)
                } else {
                    alertMessage = localizationManager.importPartialSuccessDetailed(successCount, failureCount)
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
    
    // MARK: - UI Components
    
    private var headerView: some View {
        VStack(spacing: 0) {
            // Status bar space
            Color.clear
                .frame(height: 44)
            
            // iOS-style header
            VStack(spacing: 0) {
                HStack {
                    // Library title on the left
                    Text("Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Right side buttons
                    HStack(spacing: 20) {
                        Button("Add") {
                            isShowingDocumentPicker = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Add audio files")
                        .accessibilityHint("Opens file picker to import audio files or folders")
                        
                        Button("Settings") {
                            navigateToSettings()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Opens app settings and preferences")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                
                // Sort By section
                HStack {
                    sortByMenu
                        .padding(.horizontal, 16)
                    
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
    }
    
    @ViewBuilder
    private var breadcrumbView: some View {
        if folderNavigationManager.canNavigateBack {
            BreadcrumbNavigation(folderNavigationManager: folderNavigationManager)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if folders.isEmpty && audioFiles.isEmpty {
            emptyStateView
        } else {
            mainContentView
        }
    }
    
    private var emptyStateView: some View {
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
    }
    
    private var mainContentView: some View {
        ScrollView {
            if viewMode == .grid {
                gridContentView
            } else {
                listContentView
            }
        }
    }
    
    private var gridContentView: some View {
        LazyVGrid(columns: gridColumns, spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
            // Show folders first
            ForEach(folders, id: \.self) { folder in
                FolderGridCard(
                    folder: folder,
                    artworkSize: artworkSize,
                    action: { }, // Empty action - playlist functionality handled internally
                    onDelete: { folder in
                        folderNavigationManager.deleteFolder(folder, context: viewContext)
                        refreshContent()
                    },
                    onSetCustomArtwork: setCustomArtwork,
                    onRemoveCustomArtwork: removeCustomArtwork
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
                    onShare: shareAudioFile,
                    onSetCustomArtwork: setCustomArtwork,
                    onRemoveCustomArtwork: removeCustomArtwork
                )
            }
        }
        .animation(.none, value: audioFiles.count) // Prevent layout animations on async content changes
        .animation(.none, value: folders.count)
        .accessiblePadding(.horizontal, dynamicTypeSize: dynamicTypeSize)
        .accessiblePadding(.top, dynamicTypeSize: dynamicTypeSize)
    }
    
    private var listContentView: some View {
        LazyVStack(spacing: 0) {
            // Show folders first in list mode
            ForEach(folders, id: \.self) { folder in
                VStack(spacing: 0) {
                    FolderListCard(
                        folder: folder,
                        action: { }, // Empty action - playlist functionality handled internally
                        onDelete: { folder in
                            folderNavigationManager.deleteFolder(folder, context: viewContext)
                            refreshContent()
                        },
                        onSetCustomArtwork: setCustomArtwork,
                        onRemoveCustomArtwork: removeCustomArtwork
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
                    onShare: shareAudioFile,
                    onSetCustomArtwork: setCustomArtwork,
                    onRemoveCustomArtwork: removeCustomArtwork
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
    
    private var sortByMenu: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.rawValue) { option in
                Button(action: {
                    changeSortOption(to: option)
                }) {
                    HStack {
                        Text(option.rawValue)
                        if sortOption.rawValue == option.rawValue {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityLabel("Sort by \(option.rawValue.lowercased())")
                .accessibilityHint("Changes library sort order")
            }
        } label: {
            HStack(spacing: 4) {
                Text("Sort By")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)
            }
        }
    }
    
    // MARK: - Content Management Methods
    
    private func changeSortOption(to option: SortOption) {
        sortOption = option
        loadCurrentContent()
    }
    
    private func loadCurrentContent() {
        // Throttle content loading to prevent excessive UI updates
        let now = CACurrentMediaTime()
        if now - lastContentRefresh < 0.5 || isContentLoading {
            return
        }
        
        // Ensure we're on the main thread for UI updates
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.loadCurrentContent()
            }
            return
        }
        
        isContentLoading = true
        lastContentRefresh = now
        
        folders = folderNavigationManager.getFolders(context: viewContext)
        var unsortedAudioFiles = folderNavigationManager.getAudioFiles(context: viewContext)
        
        // Apply sorting
        switch sortOption {
        case .fileName:
            unsortedAudioFiles.sort { first, second in
                return first.displayNameForSorting.isNaturallyLessThan(second.displayNameForSorting)
            }
        case .title:
            unsortedAudioFiles.sort { first, second in
                let firstTitle = first.title ?? "Unknown"
                let secondTitle = second.title ?? "Unknown"
                return firstTitle.isNaturallyLessThan(secondTitle)
            }
        case .artist:
            unsortedAudioFiles.sort { first, second in
                let firstArtist = first.artist ?? "Unknown"
                let secondArtist = second.artist ?? "Unknown"
                return firstArtist.isNaturallyLessThan(secondArtist)
            }
        case .dateAdded:
            unsortedAudioFiles.sort { ($0.dateAdded) > ($1.dateAdded) }
        case .duration:
            unsortedAudioFiles.sort { $0.duration > $1.duration }
        }
        
        audioFiles = unsortedAudioFiles
        
        // Reset loading flag asynchronously to prevent rapid successive calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isContentLoading = false
        }
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
    @EnvironmentObject var audioFileManager: AudioFileManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.managedObjectContext) private var viewContext
    let audioFile: AudioFile
    let artworkSize: CGFloat
    let action: () -> Void
    let onDelete: (AudioFile) -> Void
    let onMarkAsPlayed: (AudioFile) -> Void
    let onResetProgress: (AudioFile) -> Void
    let onShare: (AudioFile) -> Void
    let onSetCustomArtwork: (AudioFile) -> Void
    let onRemoveCustomArtwork: (AudioFile) -> Void
    
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                // Large artwork container with consistent size
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [
                                accessibilityManager.highContrastColor(base: .blue.opacity(0.2), highContrast: .black.opacity(0.4)),
                                accessibilityManager.highContrastColor(base: .purple.opacity(0.2), highContrast: .black.opacity(0.6))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: artworkSize, height: artworkSize)
                    
                    // Artwork content
                    if let artworkURL = audioFile.artworkURL {
                        LocalAsyncImageWithPhase(url: artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                return AnyView(image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: artworkSize, height: artworkSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 16)))
                            case .failure(let error):
                                let _ = print("🎨 LocalAsyncImage failed to load artwork for \(audioFile.title ?? "Unknown"): \(error)")
                                let _ = print("🎨 Artwork URL: \(artworkURL.path)")
                                let _ = print("🎨 File exists: \(FileManager.default.fileExists(atPath: artworkURL.path))")
                                return AnyView(Image(systemName: "music.note")
                                    .font(.system(size: artworkSize * 0.4))
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
                        Image(systemName: "music.note")
                            .font(.system(size: artworkSize * 0.4))
                            .foregroundColor(.white)
                            .frame(width: artworkSize, height: artworkSize)
                            .accessibilityHidden(true)
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
                                    .accessibilityLabel(audioPlayerService.isPlaying ? "Currently playing" : "Currently paused")
                                    .accessibilityHidden(true)
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
                    Text(audioFile.originalFileNameWithoutExtension)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
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
                    .fill(Color.black)
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
            .accessibilityLabel("Mark as played")
            .accessibilityHint("Sets playback progress to complete")
            
            Button(action: {
                onResetProgress(audioFile)
            }) {
                Label("Reset Progress", systemImage: "arrow.counterclockwise")
            }
            .accessibilityLabel("Reset progress")
            .accessibilityHint("Resets playback to the beginning")
            
            Divider()
            
            // Custom artwork actions
            Button(action: {
                onSetCustomArtwork(audioFile)
            }) {
                Label("Set Custom Artwork", systemImage: "photo")
            }
            .accessibilityLabel("Set custom artwork")
            .accessibilityHint("Choose a custom image as album artwork")
            
            if audioFileManager.hasCustomArtwork(for: audioFile) {
                Button(action: {
                    onRemoveCustomArtwork(audioFile)
                }) {
                    Label("Remove Custom Artwork", systemImage: "photo.badge.minus")
                }
                .accessibilityLabel("Remove custom artwork")
                .accessibilityHint("Remove the custom artwork and revert to original")
            }
            
            Divider()
            
            // Sharing action
            Button(action: {
                onShare(audioFile)
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Share audio file")
            .accessibilityHint("Opens share sheet to send this file to other apps")
            
            Divider()
            
            // Destructive action
            Button(role: .destructive, action: {
                onDelete(audioFile)
            }) {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete audio file")
            .accessibilityHint("Permanently removes this file from your library")
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
        // Only calculate progress for currently playing file to reduce CPU usage
        guard audioPlayerService.currentAudioFile == audioFile else {
            // For non-playing files, just use stored position
            return audioFile.duration > 0 ? audioFile.currentPosition / audioFile.duration : 0
        }
        
        // For currently playing file, use real-time progress
        return audioFile.duration > 0 ? audioPlayerService.currentTime / audioFile.duration : 0
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
    @EnvironmentObject var audioFileManager: AudioFileManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.managedObjectContext) private var viewContext
    let audioFile: AudioFile
    let action: () -> Void
    let onDelete: (AudioFile) -> Void
    let onMarkAsPlayed: (AudioFile) -> Void
    let onResetProgress: (AudioFile) -> Void
    let onShare: (AudioFile) -> Void
    let onSetCustomArtwork: (AudioFile) -> Void
    let onRemoveCustomArtwork: (AudioFile) -> Void
    
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
                                    accessibilityManager.highContrastColor(base: .blue.opacity(0.3), highContrast: .black.opacity(0.5)),
                                    accessibilityManager.highContrastColor(base: .purple.opacity(0.3), highContrast: .black.opacity(0.7))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 60, height: 60)
                        
                        if let artworkURL = audioFile.artworkURL {
                            LocalAsyncImageWithPhase(url: artworkURL) { phase in
                                switch phase {
                                case .success(let image):
                                    return AnyView(image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8)))
                                case .failure(let error):
                                    let _ = print("🎨 LocalAsyncImage (list) failed to load artwork for \(audioFile.title ?? "Unknown"): \(error)")
                                    return AnyView(Image(systemName: "music.note")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .accessibilityHidden(true))
                                case .empty:
                                    return AnyView(ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.6))
                                }
                            }
                        } else {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundColor(.white)
                                .accessibilityHidden(true)
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
                                        .accessibilityLabel(audioPlayerService.isPlaying ? "Currently playing" : "Currently paused")
                                        .accessibilityHidden(true)
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
                    Text(audioFile.originalFileNameWithoutExtension)
                        .dynamicTypeSupport(.headline, maxSize: .accessibility2, lineLimit: 1, allowsTightening: true)
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
                    .fill(Color.black)
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
            .accessibilityLabel("Mark as played")
            .accessibilityHint("Sets playback progress to complete")
            
            Button(action: {
                onResetProgress(audioFile)
            }) {
                Label("Reset Progress", systemImage: "arrow.counterclockwise")
            }
            .accessibilityLabel("Reset progress")
            .accessibilityHint("Resets playback to the beginning")
            
            Divider()
            
            // Custom artwork actions
            Button(action: {
                onSetCustomArtwork(audioFile)
            }) {
                Label("Set Custom Artwork", systemImage: "photo")
            }
            .accessibilityLabel("Set custom artwork")
            .accessibilityHint("Choose a custom image as album artwork")
            
            if audioFileManager.hasCustomArtwork(for: audioFile) {
                Button(action: {
                    onRemoveCustomArtwork(audioFile)
                }) {
                    Label("Remove Custom Artwork", systemImage: "photo.badge.minus")
                }
                .accessibilityLabel("Remove custom artwork")
                .accessibilityHint("Remove the custom artwork and revert to original")
            }
            
            Divider()
            
            // Sharing action
            Button(action: {
                onShare(audioFile)
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Share audio file")
            .accessibilityHint("Opens share sheet to send this file to other apps")
            
            Divider()
            
            // Destructive action
            Button(role: .destructive, action: {
                onDelete(audioFile)
            }) {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete audio file")
            .accessibilityHint("Permanently removes this file from your library")
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
        // Only calculate progress for currently playing file to reduce CPU usage
        guard audioPlayerService.currentAudioFile == audioFile else {
            // For non-playing files, just use stored position
            return audioFile.duration > 0 ? audioFile.currentPosition / audioFile.duration : 0
        }
        
        // For currently playing file, use real-time progress
        return audioFile.duration > 0 ? audioPlayerService.currentTime / audioFile.duration : 0
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
    LibraryGridView(
        navigateToPlayer: {},
        navigateToSettings: {}
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(AudioPlayerService())
    .environmentObject(AudioFileManager())
    .environmentObject(AccessibilityManager())
    .environmentObject(LocalizationManager.shared)
}

