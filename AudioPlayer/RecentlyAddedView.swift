//
//  RecentlyAddedView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/16.
//

import SwiftUI
import CoreData

struct RecentlyAddedView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AudioFile.dateAdded, ascending: false)],
        animation: .default)
    private var audioFiles: FetchedResults<AudioFile>
    
    var recentFiles: [AudioFile] {
        Array(audioFiles.prefix(50)) // Show up to 50 most recent files
    }
    
    var body: some View {
        List {
            ForEach(recentFiles, id: \.self) { audioFile in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(audioFile.title ?? "Unknown Title")
                            .font(.body)
                        
                        HStack(spacing: 8) {
                            if let artist = audioFile.artist, !artist.isEmpty {
                                Text(artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let album = audioFile.album, !album.isEmpty {
                                if audioFile.artist != nil && !audioFile.artist!.isEmpty {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(album)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(formatRecentDate(audioFile.dateAdded))
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
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
        .navigationTitle("Recently Added")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func formatRecentDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: date))"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

#Preview {
    RecentlyAddedView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AudioPlayerService())
}