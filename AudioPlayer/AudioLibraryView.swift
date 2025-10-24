//
//  AudioLibraryView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct AudioLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioFile.dateAdded, ascending: false)],
        animation: .default)
    private var audioFiles: FetchedResults<AudioFile>
    
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var audioFileManager: AudioFileManager
    
    @State private var isShowingDocumentPicker = false
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isImporting = false
    @State private var importResults: [AudioFileManager.ImportResult] = []
    @State private var isShowingDetailedResults = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if audioFiles.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Audio Files",
                        systemImage: "music.note.list",
                        description: Text("Tap the + button to import audio files")
                    )
                    Spacer()
                } else {
                    // Scrollable content area with proper safe area handling
                    List {
                        ForEach(audioFiles) { audioFile in
                            AudioFileRowView(audioFile: audioFile)
                                .onTapGesture {
                                    audioPlayerService.loadAudioFile(audioFile, context: viewContext)
                                }
                        }
                        .onDelete(perform: deleteAudioFiles)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .refreshable {
                        // Add pull-to-refresh functionality if needed in the future
                    }
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Debug artwork button (only show in debug builds)
                    #if DEBUG
                    LiquidGlassLibraryButton(
                        systemIcon: "paintbrush.pointed",
                        iconColor: .orange,
                        size: 52
                    ) {
                        debugArtwork()
                    }
                    #endif
                    
                    // Add files button with enhanced liquid glass effect
                    LiquidGlassLibraryButton(
                        systemIcon: isImporting ? "" : "plus.circle.fill",
                        iconColor: .blue,
                        size: 52,
                        showProgressView: isImporting
                    ) {
                        isShowingDocumentPicker = true
                    }
                    .disabled(isImporting)
                    
                    // Enhanced Edit/Settings button
                    if !audioFiles.isEmpty {
                        LiquidGlassLibraryButton(
                            systemIcon: "ellipsis.circle",
                            iconColor: .primary,
                            size: 52,
                            isSystemButton: true
                        ) {
                            // Edit functionality will be handled by the button itself
                        }
                    }
                }
            }
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
    
    private func deleteAudioFiles(offsets: IndexSet) {
        withAnimation {
            offsets.map { audioFiles[$0] }.forEach { audioFile in
                // Remove from all playlists first
                PlaylistManager.removeAllPlaylistItemsForAudioFile(audioFile, context: viewContext)
                
                // Delete the actual file
                if let url = audioFile.fileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                viewContext.delete(audioFile)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting audio files: \(error)")
            }
        }
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
                    alertMessage = "Failed to import \(failureCount) file(s)."
                } else {
                    alertMessage = "Imported \(successCount) file(s) successfully.\n\(failureCount) file(s) failed to import."
                }
                
                isShowingAlert = true
            }
        }
    }
    
    #if DEBUG
    private func debugArtwork() {
        print("🎨 ==== ARTWORK DEBUG SESSION ====")
        audioFileManager.listArtworkDirectory()
        audioFileManager.verifyAllArtwork(context: viewContext)
        
        // Debug first few files individually
        let sampleFiles = Array(audioFiles.prefix(3))
        for audioFile in sampleFiles {
            audioFileManager.debugArtworkStatus(for: audioFile)
        }
        print("🎨 ==== END ARTWORK DEBUG SESSION ====")
    }
    #endif
}

struct AudioFileRowView: View {
    let audioFile: AudioFile
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork or placeholder with enhanced styling
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.primary.opacity(0.7),
                                    Color.primary.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(audioFile.title ?? "Unknown Title")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(audioFile.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Original filename display
                Text(audioFile.fileName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .opacity(0.6)
                
                Text(TimeInterval(audioFile.duration).formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Enhanced play button with liquid glass effect
            Button(action: {}) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.9),
                                Color.accentColor.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .accentColor.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.primary.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
    }
}

// MARK: - Enhanced Liquid Glass Library Button

struct LiquidGlassLibraryButton: View {
    let systemIcon: String
    let iconColor: Color
    let size: CGFloat
    var showProgressView: Bool = false
    var isSystemButton: Bool = false
    let action: () -> Void
    
    @Environment(\.editMode) private var editMode
    
    init(systemIcon: String, iconColor: Color, size: CGFloat = 52, showProgressView: Bool = false, isSystemButton: Bool = false, action: @escaping () -> Void) {
        self.systemIcon = systemIcon
        self.iconColor = iconColor
        self.size = size
        self.showProgressView = showProgressView
        self.isSystemButton = isSystemButton
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if isSystemButton {
                withAnimation {
                    if editMode?.wrappedValue == .active {
                        editMode?.wrappedValue = .inactive
                    } else {
                        editMode?.wrappedValue = .active
                    }
                }
            } else {
                action()
            }
        }) {
            ZStack {
                // Enhanced multi-layered liquid glass background
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.4), location: 0.0),
                                .init(color: Color.white.opacity(0.25), location: 0.4),
                                .init(color: Color.white.opacity(0.1), location: 0.8),
                                .init(color: Color.white.opacity(0.05), location: 1.0)
                            ]),
                            center: .topLeading,
                            startRadius: 5,
                            endRadius: size
                        )
                    )
                    .overlay(
                        // Inner highlight ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .blur(radius: 0.5)
                    )
                    .overlay(
                        // Outer border ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.15)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .background(
                        // Base glass material layer
                        Circle()
                            .fill(.ultraThinMaterial)
                            .blur(radius: 3)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    .shadow(color: .white.opacity(0.6), radius: 3, x: 0, y: -3)
                    .shadow(color: iconColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Content (icon or progress view)
                if showProgressView {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: iconColor))
                } else if isSystemButton {
                    // Show different icon based on edit mode
                    Image(systemName: editMode?.wrappedValue == .active ? "checkmark.circle.fill" : systemIcon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    iconColor.opacity(0.95),
                                    iconColor.opacity(0.8),
                                    iconColor.opacity(0.6)
                                ]),
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: iconSize
                            )
                        )
                        .shadow(color: iconColor.opacity(0.5), radius: 2, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                } else {
                    Image(systemName: systemIcon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    iconColor.opacity(0.95),
                                    iconColor.opacity(0.8),
                                    iconColor.opacity(0.6)
                                ]),
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: iconSize
                            )
                        )
                        .shadow(color: iconColor.opacity(0.5), radius: 2, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
                
                // Subtle shimmer effect overlay
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.clear,
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
            }
        }
        .frame(width: size, height: size)
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(showProgressView ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: showProgressView)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode?.wrappedValue)
    }
    
    private var iconSize: CGFloat {
        size * 0.35 // Slightly larger icon for better visibility
    }
}

#Preview {
    AudioLibraryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
        .environmentObject(AudioFileManager())
}
