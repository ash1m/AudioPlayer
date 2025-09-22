//
//  AlbumsView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/16.
//

import SwiftUI
import CoreData

struct AlbumsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioFile.album, ascending: true)],
        animation: .default)
    private var audioFiles: FetchedResults<AudioFile>
    
    var groupedByAlbum: [(String, [AudioFile])] {
        let grouped = Dictionary(grouping: audioFiles) { audioFile in
            audioFile.album?.isEmpty == false ? audioFile.album! : "Unknown Album"
        }
        return grouped.map { (key, value) in
            (key, value.sorted { ($0.title ?? "") < ($1.title ?? "") })
        }.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        List {
            ForEach(groupedByAlbum, id: \.0) { album, songs in
                Section(header: 
                    HStack {
                        Image(systemName: "opticaldisc.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album)
                                .font(.headline)
                            if let artist = songs.first?.artist, !artist.isEmpty {
                                Text("by \(artist)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(songs.count) song\(songs.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                ) {
                    ForEach(songs.enumerated().map { $0 }, id: \.1) { index, audioFile in
                        HStack {
                            // Track number
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .trailing)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(audioFile.title ?? "Unknown Title")
                                    .font(.body)
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
        .navigationTitle("Albums")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    AlbumsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
}