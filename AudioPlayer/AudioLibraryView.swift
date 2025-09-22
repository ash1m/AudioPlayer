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
            if audioFiles.isEmpty {
                ContentUnavailableView(
                    "No Audio Files",
                    systemImage: "music.note.list",
                    description: Text("Tap the + button to import audio files")
                )
            } else {
                List {
                    ForEach(audioFiles) { audioFile in
                        AudioFileRowView(audioFile: audioFile)
                            .onTapGesture {
                                audioPlayerService.loadAudioFile(audioFile, context: viewContext)
                            }
                    }
                    .onDelete(perform: deleteAudioFiles)
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
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
                    .disabled(isImporting)
                    
                    if !audioFiles.isEmpty {
                        EditButton()
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
                    alertMessage = "Failed to import \(failureCount) file(s). Tap 'View Details' for more information."
                } else {
                    alertMessage = "Imported \(successCount) file(s) successfully.\n\(failureCount) file(s) failed to import. Tap 'View Details' for more information."
                }
                
                isShowingAlert = true
            }
        }
    }
}

struct AudioFileRowView: View {
    let audioFile: AudioFile
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(audioFile.title ?? "Unknown Title")
                    .font(.headline)
                Text(audioFile.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(TimeInterval(audioFile.duration).formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "play.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AudioLibraryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
        .environmentObject(AudioFileManager())
}
