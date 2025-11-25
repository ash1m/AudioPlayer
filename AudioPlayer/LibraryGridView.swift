//
//  LibraryGridView.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/16.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
import UIKit

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
    @State private var sortOption: SortOption = .fileName
    
    // Performance optimization - reduce view rebuilds
    @State private var lastContentRefresh: CFTimeInterval = 0
    @State private var isContentLoading = false
    
    // Scroll tracking for rotation effect
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                breadcrumbView
                contentView
            }
            //.navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    sortByMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingDocumentPicker = true
                    }) {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("Add audio files")
                    .accessibilityHint("Opens file picker to import audio files or folders")
                }
                    ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        navigateToSettings()
                    }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens app settings and preferences")
                }
            }
            //.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            //.toolbarBackgroundVisibility(.automatic, for: .navigationBar)
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
        // Stop playback and clear if this file is currently playing
        if audioPlayerService.currentAudioFile == audioFile {
            audioPlayerService.clearCurrentFile()
        }
        
        // Delete the actual audio file
        if let fileURL = audioFile.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Delete artwork if it exists
        if let artworkURL = audioFile.artworkURL {
            try? FileManager.default.removeItem(at: artworkURL)
        }
        
        // Remove from playlists
        PlaylistManager.removeAllPlaylistItemsForAudioFile(audioFile, context: viewContext)
        
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
                try await audioFileManager.saveCustomArtwork(for: audioFile, imageData: imageData, context: viewContext, audioPlayerService: audioPlayerService)
                
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
                try await audioFileManager.saveCustomArtwork(for: folder, imageData: imageData, context: viewContext, audioPlayerService: audioPlayerService)
                
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
            description: Text(folderNavigationManager.isInFolder ? "This folder is empty" : "Tap the 'Add' button to import audio files or folders")
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
        ScrollViewReader { scrollProxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Scroll offset tracker
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    
                    // Content
                    audioBookListView
                        .padding(.bottom, 120) // Accommodate minimized player
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                scrollOffset = -offset
            }
        }
    }
    
    private var audioBookListView: some View {
        LazyVStack(spacing: 20) {
            ForEach(Array(audioFiles.enumerated()), id: \.element.self) { index, audioFile in
                AudiobookListCard(
                    audioFile: audioFile,
                    rowIndex: index,
                    scrollOffset: scrollOffset,
                    onDelete: deleteAudioFile,
                    onTap: { handleAudioFileSelection(audioFile) },
                    onMarkAsPlayed: markAsPlayed,
                    onResetProgress: resetProgress,
                    onShare: shareAudioFile,
                    onSetCustomArtwork: setCustomArtwork,
                    onRemoveCustomArtwork: removeCustomArtwork
                )
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity.combined(with: .scale(scale: 0.8))
                ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
                    .font(FontManager.fontWithSystemFallback(weight: .semibold, size: FontManager.FontSize.body))
                    .foregroundColor(.blue)
                Image(systemName: "chevron.down")
                    .font(FontManager.fontWithSystemFallback(weight: .medium, size: FontManager.FontSize.caption))
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

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
