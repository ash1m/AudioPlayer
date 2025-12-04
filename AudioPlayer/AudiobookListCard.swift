//
//  AudiobookListCard.swift
//  FireVox
//
//  Created by Assistant on 2025/11/11.
//

import SwiftUI
import CoreData

struct AudiobookListCard: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) var sizeClass
    
    let audioFile: AudioFile
    let rowIndex: Int
    let onDelete: (AudioFile) -> Void
    let onTap: () -> Void
    let onMarkAsPlayed: ((AudioFile) -> Void)?
    let onResetProgress: ((AudioFile) -> Void)?
    let onShare: ((AudioFile) -> Void)?
    let onSetCustomArtwork: ((AudioFile) -> Void)?
    let onRemoveCustomArtwork: ((AudioFile) -> Void)?
    let totalGroupDuration: Double?  // Total duration if this represents a group of files
    
    @State private var dominantColor: Color = Color.gray.opacity(0.2)
    @State private var screenWidth: CGFloat = 390
    @State private var initialRotation: Double = 0
    @State private var showContextMenu: Bool = false

    
    private let maxRotation: CGFloat = 3.0
    
    private var isImageLeft: Bool {
        rowIndex % 2 == 0
    }
    
    // Get screen width - 50% of device width
    private var coverSize: CGFloat {
        return screenWidth * 0.4
    }
   
    private var infoTextWidth: CGFloat {
        return screenWidth * 0.6
    }

    private var marginWidth: CGFloat {
        return screenWidth * 0.1
    }

    private var totalRowWidth: CGFloat {
        // 40% image + 60% infotext + 10% margin (on one side for bleed)
        return coverSize + infoTextWidth + marginWidth
    }
 

    var body: some View {
        GeometryReader { geometry in
            ZStack() {
                HStack(spacing: 0) {
                    
                    if isImageLeft {
                        
                        // Image
                        coverImageSection(geometry: geometry)
                            .padding(.trailing, marginWidth)
                            .frame(width: coverSize)
                        
                        // InfoText
                        textSection
                            .frame(width: infoTextWidth)

                        // Margin (bleeds off-screen)
                        Color.clear
                            .frame(width: marginWidth)
                        
                    }
                    else {
                        
                        // InfoText
                        textSection
                            .padding(.leading, marginWidth*0.25)
                            .frame(width: infoTextWidth)
                        
                        // Image
                        coverImageSection(geometry: geometry)
                            .frame(width: coverSize)

                        // Margin (bleeds off-screen)
                        //Color.clear
                        //    .frame(width: marginWidth)
                    }
                }
                .frame(maxWidth: totalRowWidth, alignment: .center)
                //.padding()
            }
        }
    .frame(height: coverSize + 32)  // coverSize + padding (16 top + 16 bottom)
    .onTapGesture(perform: onTap)
    .contextMenu {
        // Playback actions
        if onMarkAsPlayed != nil {
            Button(action: {
                onMarkAsPlayed?(audioFile)
            }) {
                Label("Mark as Played", systemImage: "checkmark.circle")
            }
            .accessibilityLabel("Mark as played")
            .accessibilityHint("Sets playback progress to complete")
        }
        
        if onResetProgress != nil {
            Button(action: {
                onResetProgress?(audioFile)
            }) {
                Label("Reset Progress", systemImage: "arrow.counterclockwise")
            }
            .accessibilityLabel("Reset progress")
            .accessibilityHint("Resets playback to the beginning")
        }
        
        if onMarkAsPlayed != nil || onResetProgress != nil {
            Divider()
        }
        
        // Custom artwork actions
        if onSetCustomArtwork != nil {
            Button(action: {
                onSetCustomArtwork?(audioFile)
            }) {
                Label("Set Custom Artwork", systemImage: "photo")
            }
            .accessibilityLabel("Set custom artwork")
            .accessibilityHint("Choose a custom image as album artwork")
        }
        
        if onRemoveCustomArtwork != nil {
            Button(action: {
                onRemoveCustomArtwork?(audioFile)
            }) {
                Label("Remove Custom Artwork", systemImage: "photo")
            }
            .accessibilityLabel("Remove custom artwork")
            .accessibilityHint("Remove the custom artwork and revert to original")
        }
        
        if onSetCustomArtwork != nil || onRemoveCustomArtwork != nil {
            Divider()
        }
        
        // Sharing action
        if onShare != nil {
            Button(action: {
                onShare?(audioFile)
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Share audio file")
            .accessibilityHint("Opens share sheet to send this file to other apps")
            
            Divider()
        }
        
        // Destructive action
        Button(role: .destructive, action: { onDelete(audioFile) }) {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityLabel("Delete audio file")
        .accessibilityHint("Permanently removes this file from your library")
    }
        .onAppear {
            // Capture screen width from the window scene
            if let screenWidth = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?
                .screen
                .bounds.width {
                self.screenWidth = screenWidth
            }
            
            // Set random initial rotation between -4 and +4 degrees
            initialRotation = Double.random(in: -maxRotation...maxRotation)
            //updateRotation()
        }
        .onDisappear {
            // no-op
        }
        .task {
            if let artworkURL = audioFile.artworkURL {
                let color = await DominantColorExtractor.shared.extractMostUsedColor(from: artworkURL)
                await MainActor.run {
                    dominantColor = color
                }
            }
        }
    }
    
    // MARK: - Rotation Calculation
    
    private func rotation(for geometry: GeometryProxy) -> Double {
        // Get the card's current Y position relative to its container
        let currentY = geometry.frame(in: .named("scroll")).minY
        
        // Calculate how far it's scrolled (negative = scrolled up)
        let scrollProgress = abs(currentY) / 250
        let scrollRotation = maxRotation * min(scrollProgress, 1.0)
        return initialRotation + scrollRotation
    }
    
    // MARK: - UI Components
    
    private func coverImageSection(geometry: GeometryProxy) -> some View {
        //let bleedAmount = coverSize * 0.2
        let rotation = rotation(for: geometry)
        
        return ZStack(alignment: .center) {
            Rectangle()
                .fill(dominantColor)
                .frame(width: coverSize * 1.1, height: coverSize * 1.1)
                .rotationEffect(.degrees(rotation))
            
            if let artworkURL = audioFile.artworkURL {
                LocalAsyncImageWithPhase(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        return AnyView(image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize, height: coverSize)
                            .clipShape(RoundedRectangle(cornerRadius: 0))
                            .rotationEffect(.degrees(rotation))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4))
                    
                    case .failure:
                        return AnyView(Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                            .frame(width: coverSize, height: coverSize)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12)))
                    
                    case .empty:
                        return AnyView(ProgressView()
                            .frame(width: coverSize, height: coverSize))
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                    .frame(width: coverSize, height: coverSize)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(width: coverSize, height: coverSize)
        //.offset(x: isImageLeft ? bleedAmount : -bleedAmount)
    }
    
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Header with title and menu button
                VStack(alignment: .leading, spacing: 3) {
                    Text(audioFile.title ?? audioFile.originalFileNameWithoutExtension)
                        .font(.custom("TiemposText-Bold", size: 24))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)  // ADD THIS
                            .fixedSize(horizontal: false, vertical: true)  // ADD THIS
                    
                    Text(audioFile.artist ?? "Unknown Author")
                        .font(FontManager.fontWithSystemFallback(weight: .regular, size: 16))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Duration
                    let displayDuration = totalGroupDuration ?? audioFile.duration
                    Text(TimeInterval(displayDuration).formattedDuration)
                        .font(FontManager.fontWithSystemFallback(weight: .regular, size: 14))
                        .foregroundColor(.primary)
        
                
                // Three-dot menu button
                Menu {
                    // Playback actions
                    Button(action: {
                        onMarkAsPlayed?(audioFile)
                    }) {
                        Label("Mark as Played", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: {
                        onResetProgress?(audioFile)
                    }) {
                        Label("Reset Progress", systemImage: "arrow.counterclockwise")
                    }
                    
                    Divider()
                    
                    // Custom artwork actions
                    Button(action: {
                        onSetCustomArtwork?(audioFile)
                    }) {
                        Label("Set Custom Artwork", systemImage: "photo")
                    }
                    
                    if onRemoveCustomArtwork != nil {
                        Button(action: {
                            onRemoveCustomArtwork?(audioFile)
                        }) {
                            Label("Remove Custom Artwork", systemImage: "photo")
                        }
                    }
                    
                    Divider()
                    
                    // Sharing action
                    Button(action: {
                        onShare?(audioFile)
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    // Destructive action
                    Button(role: .destructive, action: { onDelete(audioFile) }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
/*                        .background(
                            ZStack {
                                // Glass effect
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(.ultraThinMaterial)
                                
                                // Subtle border
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            }
                        )*/
                        .contentShape(Circle())
                }
            }
            

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}
