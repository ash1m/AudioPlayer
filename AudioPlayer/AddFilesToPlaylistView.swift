//
//  AddFilesToPlaylistView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/20.
//

import SwiftUI
import CoreData

struct AddFilesToPlaylistView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioFile.title, ascending: true)],
        animation: .default
    ) private var audioFiles: FetchedResults<AudioFile>
    
    @State private var selectedFiles: Set<AudioFile> = []
    @State private var searchText = ""
    @State private var isAdding = false
    
    // Filter audio files based on search text and exclude already added files
    private var filteredAudioFiles: [AudioFile] {
        let playlistItemFiles = playlistManager.currentPlaylist?.orderedItems.compactMap { $0.audioFile } ?? []
        let playlistFileIDs = Set(playlistItemFiles.map { $0.id })
        
        var availableFiles = audioFiles.filter { !playlistFileIDs.contains($0.id) }
        
        if !searchText.isEmpty {
            availableFiles = availableFiles.filter { audioFile in
                let title = audioFile.title?.localizedCaseInsensitiveContains(searchText) ?? false
                let artist = audioFile.artist?.localizedCaseInsensitiveContains(searchText) ?? false
                let album = audioFile.album?.localizedCaseInsensitiveContains(searchText) ?? false
                return title || artist || album
            }
        }
        
        return availableFiles
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                if filteredAudioFiles.isEmpty {
                    emptyStateView
                } else {
                    filesList
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add (\(selectedFiles.count))") {
                        addSelectedFiles()
                    }
                    .disabled(selectedFiles.isEmpty || isAdding)
                    .opacity(selectedFiles.isEmpty ? 0.6 : 1.0)
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            TextField("Search files...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityLabel("Search audio files")
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AccessibleSpacing.standard(for: dynamicTypeSize))
        .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, AccessibleSpacing.standard(for: dynamicTypeSize))
        .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
            Spacer()
            
            Image(systemName: searchText.isEmpty ? "music.note.list" : "magnifyingglass")
                .font(FontManager.font(.regular, size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(searchText.isEmpty ? "All files already added" : "No matching files")
                .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .visualAccessibility(foreground: .secondary)
            
            if searchText.isEmpty {
                Text("All your imported audio files are already in the playlist")
                    .font(FontManager.font(.regular, size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AccessibleSpacing.expanded(for: dynamicTypeSize))
                    .visualAccessibility(foreground: .secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Files List
    
    private var filesList: some View {
        List {
            Section {
                ForEach(filteredAudioFiles, id: \.id) { audioFile in
                    AddFileRow(
                        audioFile: audioFile,
                        isSelected: selectedFiles.contains(audioFile),
                        onToggle: {
                            toggleSelection(for: audioFile)
                        }
                    )
                }
            } header: {
                HStack {
                    Text("\(filteredAudioFiles.count) available files")
                        .font(FontManager.font(.regular, size: 15))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if selectedFiles.count < filteredAudioFiles.count {
                        Button("Select All") {
                            selectedFiles = Set(filteredAudioFiles)
                        }
                        .font(FontManager.font(.regular, size: 15))
                        .accessibilityLabel("Select all available files")
                    } else if !selectedFiles.isEmpty {
                        Button("Deselect All") {
                            selectedFiles.removeAll()
                        }
                        .font(FontManager.font(.regular, size: 15))
                        .accessibilityLabel("Deselect all files")
                    }
                }
                .textCase(nil)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Actions
    
    private func toggleSelection(for audioFile: AudioFile) {
        if selectedFiles.contains(audioFile) {
            selectedFiles.remove(audioFile)
        } else {
            selectedFiles.insert(audioFile)
        }
    }
    
    private func addSelectedFiles() {
        guard !selectedFiles.isEmpty else { return }
        
        isAdding = true
        
        let filesToAdd = Array(selectedFiles)
        playlistManager.addAudioFiles(filesToAdd)
        
        // Haptic feedback for successful addition
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        dismiss()
    }
}

// MARK: - Add File Row

struct AddFileRow: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    let audioFile: AudioFile
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(FontManager.font(.regular, size: 22))
                    .foregroundColor(isSelected ? 
                        accessibilityManager.highContrastColor(base: .blue, highContrast: .primary) : 
                        .secondary
                    )
                    .accessibilityHidden(true)
                
                // Artwork thumbnail
                LocalAsyncImageWithPhase(url: audioFile.artworkURL) { phase in
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
                    Text(audioFile.title ?? "Unknown Title")
                        .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 17))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .visualAccessibility()
                    
                    Text(audioFile.artist ?? "Unknown Artist")
                        .font(FontManager.font(.regular, size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .visualAccessibility(foreground: .secondary)
                    
                    // Original filename display
                    Text(audioFile.fileName)
                        .font(FontManager.font(.regular, size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(0.6)
                        .visualAccessibility(foreground: .secondary)
                    
                    if audioFile.duration > 0 {
                        Text(TimeInterval(audioFile.duration).formattedDuration)
                            .font(FontManager.font(.regular, size: 12))
                            .foregroundColor(.secondary)
                            .visualAccessibility(foreground: .secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isSelected ? "Selected" : "Not selected"), \(audioFile.title ?? "Unknown Title") by \(audioFile.artist ?? "Unknown Artist")")
        .accessibilityHint("Tap to \(isSelected ? "deselect" : "select") for playlist")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    AddFilesToPlaylistView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(PlaylistManager(context: PersistenceController.preview.container.viewContext))
        .environmentObject(AccessibilityManager())
}