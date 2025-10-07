//
//  SlideUpPlayerView.swift
//  AudioPlayer
//
//  Created by Assistant on 2025/10/04.
//

import SwiftUI
import CoreData

enum PlayerState {
    case minimized
    case expanded
}

struct SlideUpPlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    @State private var playerState: PlayerState = .minimized
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingSpeedOptions = false
    @State private var isShowingSleepTimer = false
    @State private var isShowingPlaylist = false
    
    private let minimizedHeight: CGFloat = 102
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                // Player content
                playerContent
                    .frame(height: playerHeight(geometry: geometry))
                    .background(
                        Group {
                            if playerState == .expanded {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(.systemGray6))
                                    .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: -2)
                            } else {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: -2)
                            }
                        }
                    )
                    //.offset(y: dragOffset)
                    //.animation(.spring(response: 0.5, dampingFraction: 0.8), value: playerState)
                    //.animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
                    .gesture(dragGesture)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .sheet(isPresented: $isShowingSleepTimer) {
            SleepTimerView()
        }
        .sheet(isPresented: $isShowingPlaylist) {
            PlaylistView()
        }
        .confirmationDialog("Playback Speed", isPresented: $isShowingSpeedOptions, titleVisibility: .visible) {
            speedDialogButtons
        }
    }
    
    @ViewBuilder
    private var speedDialogButtons: some View {
        Button("0.5x") {
            audioPlayerService.setPlaybackRate(0.5)
            accessibilityManager.announceMessage("Playback speed set to 0.5x speed")
        }
        .accessibilityLabel("0.5x speed")
        
        Button("0.75x") {
            audioPlayerService.setPlaybackRate(0.75)
            accessibilityManager.announceMessage("Playback speed set to 0.75x speed")
        }
        .accessibilityLabel("0.75x speed")
        
        Button("1.0x") {
            audioPlayerService.setPlaybackRate(1.0)
            accessibilityManager.announceMessage("Playback speed set to normal speed")
        }
        .accessibilityLabel("Normal speed")
        
        Button("1.25x") {
            audioPlayerService.setPlaybackRate(1.25)
            accessibilityManager.announceMessage("Playback speed set to 1.25x speed")
        }
        .accessibilityLabel("1.25x speed")
        
        Button("1.5x") {
            audioPlayerService.setPlaybackRate(1.5)
            accessibilityManager.announceMessage("Playback speed set to 1.5x speed")
        }
        .accessibilityLabel("1.5x speed")
        
        Button("2.0x") {
            audioPlayerService.setPlaybackRate(2.0)
            accessibilityManager.announceMessage("Playback speed set to 2x speed")
        }
        .accessibilityLabel("2x speed")
        
        Button("Cancel", role: .cancel) { }
    }
    
    @ViewBuilder
    private var playerContent: some View {
        if playerState == .minimized {
            minimizedPlayer
        } else {
            expandedPlayer
        }
    }
    
    private var minimizedPlayer: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            HStack(spacing: 12) {
                // Progress bar (takes most space)
                progressBarMinimized
                    .frame(height: 44)
                
                // Play/Pause button
                playPauseButtonMinimized
                    .frame(width: 64, height: 64)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 17)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                playerState = .expanded
            }
        }
    }
    
    private var expandedPlayer: some View {
        VStack(spacing: 0) {
            // Status bar space with dismiss button
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        audioPlayerService.clearCurrentFile()
                        dragOffset = 0
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .accessibilityLabel("Close player")
                .accessibilityHint("Double tap to close the audio player")
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 28)
            
            // Main player content
            VStack(spacing: 28) {
                // Album artwork
                albumArtworkExpanded
                
                // Song info card
                songInfoCard
                
                // Progress bar
                progressBarExpanded
                
                // Control buttons
                controlButtons
                
                // Bottom options
                bottomOptions
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 16)
            
            Spacer()
        }
    }
    
    private var albumArtworkExpanded: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.white)
            .frame(width: 320, height: 320)
            .overlay(
                Group {
                    if let artworkURL = audioPlayerService.currentAudioFile?.artworkURL {
                        LocalAsyncImageWithPhase(url: artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                return AnyView(image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 15)))
                            case .failure(let error):
                                let _ = print("🎨 LocalAsyncImage (slideup) failed to load artwork: \(error)")
                                return AnyView(Image(systemName: "music.note")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray))
                            case .empty:
                                return AnyView(ProgressView()
                                    .scaleEffect(1.2))
                            }
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    }
                }
            )
    }
    
    private var songInfoCard: some View {
        Button(action: {
            isShowingPlaylist = true
        }) {
            HStack(spacing: 8) {
                // Playlist icon
                Circle()
                    .fill(Color(.systemGray2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    )
                
                // Title and artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioPlayerService.currentAudioFile?.title ?? "Title Long One Line Second")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(audioPlayerService.currentAudioFile?.artist ?? "Author Name Long One")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Open playlist")
        .accessibilityHint("Double tap to view and manage your playlist")
        .accessibilityAddTraits(.isButton)
    }
    
    private var progressBarExpanded: some View {
        VStack(spacing: 0) {
            // Progress track
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue)
                    .frame(width: progressWidth, height: 6)
            }
            .onTapGesture { location in
                let progress = location.x / 320 // Full width
                let newTime = progress * audioPlayerService.duration
                audioPlayerService.seek(to: max(0, min(newTime, audioPlayerService.duration)))
            }
        }
        .frame(height: 44)
    }
    
    private var progressBarMinimized: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.2))
                .frame(height: 6)
            
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.blue)
                .frame(width: progressWidthMinimized, height: 6)
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 22) {
            // Rewind button
            GlassMorphismButton(systemIcon: "gobackward.15") {
                audioPlayerService.rewind15()
            }
            
            // Play/Pause button  
            GlassMorphismButton(
                systemIcon: audioPlayerService.isPlaying ? "pause" : "play.fill",
                size: 80
            ) {
                audioPlayerService.togglePlayback()
            }
            
            // Fast forward button
            GlassMorphismButton(systemIcon: "goforward.15") {
                audioPlayerService.fastForward15()
            }
        }
    }
    
    private var playPauseButtonMinimized: some View {
        GlassMorphismButton(
            systemIcon: audioPlayerService.isPlaying ? "pause" : "play.fill",
            size: 64
        ) {
            audioPlayerService.togglePlayback()
        }
    }
    
    private var bottomOptions: some View {
        HStack {
            // Sleep timer button
            Button(action: { isShowingSleepTimer = true }) {
                HStack(spacing: 4) {
                    Text("Sleep")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Speed button
            Button(action: { isShowingSpeedOptions = true }) {
                HStack(spacing: 4) {
                    Text("\(audioPlayerService.playbackRate, specifier: "%.1f")x")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(width: 252)
    }
    
    // MARK: - Computed Properties
    
    private var progressWidth: CGFloat {
        guard audioPlayerService.duration > 0 else { return 6 }
        let progress = audioPlayerService.currentTime / audioPlayerService.duration
        return max(6, 320 * progress) // 320 is the full width, minimum 6 for the knob
    }
    
    private var progressWidthMinimized: CGFloat {
        guard audioPlayerService.duration > 0 else { return 6 }
        let progress = audioPlayerService.currentTime / audioPlayerService.duration
        let availableWidth = 280.0 // Approximate width, will be adjusted by frame
        return max(6, availableWidth * progress)
    }
    
    private func playerHeight(geometry: GeometryProxy) -> CGFloat {
        switch playerState {
        case .minimized:
            return minimizedHeight
        case .expanded:
            return geometry.size.height
        }
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.height // CGSize uses height, not y
                
                if playerState == .minimized {
                    // Allow upward drag (negative) for expansion and downward drag (positive) for dismissal
                    dragOffset = translation
                } else {
                    // Only allow downward drag when expanded
                    dragOffset = max(0, translation)
                }
            }
            .onEnded { value in
                let translation = value.translation.height // CGSize uses height, not y
                
                // Simplified gesture handling without velocity
                // Use only translation distance for determining state change
                withAnimation(.spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0.5))
                
                {
                    if playerState == .minimized {
                        // Dismiss if dragged down significantly from minimized state
                        if translation > 80 {
                            audioPlayerService.clearCurrentFile()
                            dragOffset = 0
                        }
                        // Expand if dragged up significantly
                        else if translation < -50 {
                            playerState = .expanded
                        }
                    } else {
                        // Minimize if dragged down significantly from expanded state
                        if translation > 100 {
                            playerState = .minimized
                        }
                        // Dismiss if dragged down very far from expanded state
                        else if translation > 200 {
                            audioPlayerService.clearCurrentFile()
                            dragOffset = 0
                        }
                    }
                    
                    // Reset drag offset if not dismissing
                    if audioPlayerService.currentAudioFile != nil {
                        dragOffset = 0
                    }
                }
            }
    }
}

// MARK: - Glass Morphism Button

struct GlassMorphismButton: View {
    let systemIcon: String
    let size: CGFloat
    let action: () -> Void
    
    init(systemIcon: String, size: CGFloat = 80, action: @escaping () -> Void) {
        self.systemIcon = systemIcon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Glass morphism background
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                // Icon
                Image(systemName: systemIcon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: size, height: size)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconSize: CGFloat {
        size * 0.24 // Scale icon relative to button size
    }
}

#Preview {
    SlideUpPlayerView()
        .environmentObject(AudioPlayerService())
        .environmentObject(AccessibilityManager())
        .background(Color.black)
}
