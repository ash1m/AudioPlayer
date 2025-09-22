//
//  AllSongsView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/16.
//

import SwiftUI
import CoreData

struct AllSongsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioFile.title, ascending: true)],
        animation: .default)
    private var audioFiles: FetchedResults<AudioFile>
    
    var body: some View {
        List {
            ForEach(audioFiles) { audioFile in
                AudioFileRowView(audioFile: audioFile)
                    .onTapGesture {
                        audioPlayerService.loadAudioFile(audioFile, context: viewContext)
                    }
            }
            .onDelete(perform: deleteAudioFiles)
        }
        .navigationTitle("All Songs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !audioFiles.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
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
}

#Preview {
    AllSongsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
}