//
//  ArtistsView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/16.
//

import SwiftUI
import CoreData

struct ArtistsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioFile.artist, ascending: true)],
        animation: .default)
    private var audioFiles: FetchedResults<AudioFile>
    
    var groupedByArtist: [(String, [AudioFile])] {
        let grouped = Dictionary(grouping: audioFiles) { audioFile in
            audioFile.artist?.isEmpty == false ? audioFile.artist! : "Unknown Artist"
        }
        return grouped.map { (key, value) in
            (key, value.sorted { ($0.title ?? "") < ($1.title ?? "") })
        }.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        List {
            ForEach(groupedByArtist, id: \.0) { artist, songs in
                Section(header: 
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        Text(artist)
                            .font(.headline)
                        Spacer()
                        Text("\(songs.count) song\(songs.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                ) {
                    ForEach(songs, id: \.self) { audioFile in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(audioFile.title ?? "Unknown Title")
                                    .font(.body)
                                if let album = audioFile.album, !album.isEmpty {
                                    Text(album)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Original filename display
                                Text(audioFile.fileName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .opacity(0.6)
                                
                                if audioFile.duration > 0 {
                                    Text(TimeInterval(audioFile.duration).formattedDuration)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            audioPlayerService.loadAudioFile(audioFile, context: viewContext)
                        }
                    }
                }
            }
        }
        .navigationTitle("Artists")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    ArtistsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
}