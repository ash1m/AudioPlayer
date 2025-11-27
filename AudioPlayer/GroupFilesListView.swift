//
//  GroupFilesListView.swift
//  FireVox
//
//  Created by Assistant on 2025/11/26.
//

import SwiftUI
import CoreData

struct GroupFilesListView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    
    let files: [AudioFile]
    let currentIndex: Int
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                    GroupFileRow(
                        file: file,
                        index: index,
                        totalCount: files.count,
                        isCurrentlyPlaying: index == currentIndex,
                        onSelect: {
                            // Play the selected file from this index
                            audioPlayerService.playGroupedFiles(files, startingAt: index, context: viewContext)
                        }
                    )
                }
            }
            .navigationTitle("Audiobook Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GroupFileRow: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Environment(\.dismiss) var dismiss
    
    let file: AudioFile
    let index: Int
    let totalCount: Int
    let isCurrentlyPlaying: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            onSelect()
            dismiss()
        }) {
            HStack(spacing: 12) {
                // File index
                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(isCurrentlyPlaying ? Color.blue : Color.white.opacity(0.2))
                    .cornerRadius(8)
                
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.title ?? "Untitled")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(formatTime(file.duration))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                        
                        if let lastPlayed = file.lastPlayed {
                            Text("•")
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(lastPlayedText(lastPlayed))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                // Playing indicator
                if isCurrentlyPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.black.opacity(0.3))
        .accessibilityLabel("File \(index + 1): \(file.title ?? "Untitled")")
        .accessibilityValue("\(formatTime(file.duration))\(isCurrentlyPlaying ? ", currently playing" : "")")
        .accessibilityHint("Double tap to play")
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func lastPlayedText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    GroupFilesListView(
        files: [
            AudioFile(context: PersistenceController.preview.container.viewContext),
            AudioFile(context: PersistenceController.preview.container.viewContext),
        ],
        currentIndex: 0
    )
    .environmentObject(AudioPlayerService())
}
