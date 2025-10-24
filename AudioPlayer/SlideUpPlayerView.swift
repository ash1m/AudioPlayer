//
//  SlideUpPlayerView.swift
//  AudioPlayer
//
//  Created by Assistant on 2025/10/04.
//

import SwiftUI
import CoreData
import UIKit

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
    
    // Cached computed properties to reduce body computation
    @State private var cachedMiniPlayerLabel = ""
    @State private var cachedMiniPlayerValue = ""
    @State private var cachedTimelineValue = ""
    @State private var lastUIUpdateTime: CFTimeInterval = 0
    
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
                                    .fill(Color.black) // Dark mode background
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
        .onChange(of: audioPlayerService.currentTime) {
            throttleUIUpdates()
        }
        .onChange(of: audioPlayerService.isPlaying) {
            updateCachedLabels()
        }
        .onChange(of: audioPlayerService.currentAudioFile?.title) {
            updateCachedLabels()
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
                .accessibilityHidden(true)
            
            HStack(spacing: 12) {
                // Progress bar (takes most space)
                progressBarMinimized
                    .frame(height: 44)
                    .accessibilityHidden(true)
                
                // Play/Pause button
                playPauseButtonMinimized
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 17)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(cachedMiniPlayerLabel.isEmpty ? miniPlayerAccessibilityLabel : cachedMiniPlayerLabel)
        .accessibilityHint("Double-tap to expand player")
        .accessibilityValue(cachedMiniPlayerValue.isEmpty ? miniPlayerAccessibilityValue : cachedMiniPlayerValue)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                playerState = .expanded
                // Announce the expansion to VoiceOver users
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    accessibilityManager.announceMessage("Full player now open")
                }
            }
        }
    }
    
    private var expandedPlayer: some View {
        AccessibleExpandedPlayer {
            VStack(spacing: 0) {
                // Drag handle at top
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 80, height: 5)
                    .padding(.top, 12)
                    .accessibilityHidden(true)
                
                // Main content with proper spacing
                VStack(spacing: 40) {
                    // Book artwork with overlay details
                    bookArtworkWithDetails
                    
                    // Playback controls group
                    playbackControlsGroup
                    
                    // Control buttons
                    controlButtons
                    
                    // Bottom options (Sleep/Speed)
                    bottomOptions
                }
                .padding(.top, 0)
                
                Spacer(minLength: 40) // Bottom spacing
            }
        } onEscape: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                playerState = .minimized
                accessibilityManager.announceMessage("Player minimized")
            }
        }
    }
    
    private var bookArtworkWithDetails: some View {
        ZStack(alignment: .bottom) {
            artworkBackground
            gradientOverlay
            bookDetailsOverlay
        }
        .frame(height: 376)
        .frame(maxWidth: .infinity)
    }
    
    private var artworkBackground: some View {
        RoundedRectangle(cornerRadius: 25)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Group {
                    if let artworkURL = audioPlayerService.currentAudioFile?.artworkURL {
                        LocalAsyncImageWithPhase(url: artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                return AnyView(image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped())
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
                            .accessibilityHidden(true)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 25))
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color.black.opacity(0.7), location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
    
    private var bookDetailsOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(audioPlayerService.currentAudioFile?.title ?? "Title Long One Line Second")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(audioPlayerService.currentAudioFile?.artist ?? "Author Name Long One")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var playbackControlsGroup: some View {
        VStack(spacing: 0) {
            // Timestamps
            HStack {
                Text(formatTime(audioPlayerService.currentTime))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)
                    .accessibilityLabel("Current time \(formatTimeForAccessibility(audioPlayerService.currentTime))")
                
                Spacer()
                
                Text(formatTime(audioPlayerService.duration))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)
                    .accessibilityLabel("Total duration \(formatTimeForAccessibility(audioPlayerService.duration))")
            }
            .frame(maxWidth: 313)
            
            // Timeline with custom slider
            customTimelineSlider
                .frame(height: 52)
        }
        .frame(height: 91)
        .frame(maxWidth: 343)
    }
    
    private var customTimelineSlider: some View {
        VStack(spacing: 0) {
            // Separator line
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
            
            // Slider area
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress track (invisible, just for positioning)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.clear)
                        .frame(width: progressWidthForGeometry(geometry), height: 6)
                    
                    // Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 0.5)
                        .shadow(color: .black.opacity(0.12), radius: 6.5, x: 0, y: 6)
                        .offset(x: progressWidthForGeometry(geometry) - 12) // Position knob at progress point
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .accessibilityElement()
                .accessibilityLabel("Timeline scrubber")
                .accessibilityHint("Double tap to adjust playback position")
                .accessibilityValue(cachedTimelineValue.isEmpty ? timelineAccessibilityValue : cachedTimelineValue)
                .accessibilityAction(named: "Skip forward 15 seconds") {
                    let newTime = min(audioPlayerService.duration, audioPlayerService.currentTime + 15.0)
                    audioPlayerService.seek(to: newTime)
                }
                .accessibilityAction(named: "Skip backward 15 seconds") {
                    let newTime = max(0, audioPlayerService.currentTime - 15.0)
                    audioPlayerService.seek(to: newTime)
                }
                .onTapGesture { location in
                    let sliderWidth = geometry.size.width
                    let progress = min(1.0, max(0.0, location.x / sliderWidth))
                    let newTime = progress * audioPlayerService.duration
                    audioPlayerService.seek(to: max(0, min(newTime, audioPlayerService.duration)))
                }
            }
            .frame(height: 51)
            .padding(.horizontal, 16)
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatTimeForAccessibility(_ time: Double) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Accessibility Properties
    
    private var miniPlayerAccessibilityLabel: String {
        guard let currentFile = audioPlayerService.currentAudioFile else {
            return "Audio player"
        }
        
        let title = currentFile.title ?? "Unknown title"
        let artist = currentFile.artist ?? "Unknown artist"
        let playbackStatus = audioPlayerService.isPlaying ? "Playing" : "Paused"
        
        return "Now \(playbackStatus.lowercased()): \(title) by \(artist)"
    }
    
    private var miniPlayerAccessibilityValue: String {
        guard audioPlayerService.duration > 0 else {
            return "No duration information"
        }
        
        let remaining = audioPlayerService.duration - audioPlayerService.currentTime
        let remainingFormatted = formatTimeForAccessibility(remaining)
        let currentFormatted = formatTimeForAccessibility(audioPlayerService.currentTime)
        let durationFormatted = formatTimeForAccessibility(audioPlayerService.duration)
        
        return "\(currentFormatted) of \(durationFormatted), \(remainingFormatted) remaining"
    }
    
    private var timelineAccessibilityValue: String {
        let currentFormatted = formatTimeForAccessibility(audioPlayerService.currentTime)
        let durationFormatted = formatTimeForAccessibility(audioPlayerService.duration)
        return "\(currentFormatted) of \(durationFormatted)"
    }
    
    // MARK: - Performance Optimization Methods
    
    private func throttleUIUpdates() {
        // Ensure we're on the main thread for UI updates
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.throttleUIUpdates()
            }
            return
        }
        
        let now = CACurrentMediaTime()
        let timeSinceLastUpdate = now - lastUIUpdateTime
        
        // Throttle UI updates to 1Hz maximum (every 1 second) to reduce CPU usage
        if timeSinceLastUpdate >= 1.0 {
            updateCachedLabels()
            lastUIUpdateTime = now
        }
    }
    
    private func updateCachedLabels() {
        // Ensure we're on the main thread for state updates
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.updateCachedLabels()
            }
            return
        }
        
        // Cache expensive computed properties to reduce view rebuilds
        cachedMiniPlayerLabel = miniPlayerAccessibilityLabel
        cachedMiniPlayerValue = miniPlayerAccessibilityValue
        cachedTimelineValue = timelineAccessibilityValue
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
            GlassMorphismButton(
                systemIcon: "gobackward.15",
                accessibilityLabel: "Rewind 15 seconds",
                accessibilityHint: "Moves playback backward by 15 seconds"
            ) {
                audioPlayerService.rewind15()
            }
            
            // Play/Pause button  
            GlassMorphismButton(
                systemIcon: audioPlayerService.isPlaying ? "pause" : "play.fill",
                size: 80,
                accessibilityLabel: audioPlayerService.isPlaying ? "Pause" : "Play",
                accessibilityHint: audioPlayerService.isPlaying ? "Pauses audio playback" : "Starts audio playback"
            ) {
                audioPlayerService.togglePlayback()
            }
            
            // Fast forward button
            GlassMorphismButton(
                systemIcon: "goforward.15",
                accessibilityLabel: "Fast forward 15 seconds",
                accessibilityHint: "Moves playback forward by 15 seconds"
            ) {
                audioPlayerService.fastForward15()
            }
        }
    }
    
    private var playPauseButtonMinimized: some View {
        GlassMorphismButton(
            systemIcon: audioPlayerService.isPlaying ? "pause" : "play.fill",
            size: 64,
            accessibilityLabel: audioPlayerService.isPlaying ? "Pause" : "Play",
            accessibilityHint: audioPlayerService.isPlaying ? "Pauses audio playback" : "Starts audio playback"
        ) {
            audioPlayerService.togglePlayback()
        }
    }
    
    private var bottomOptions: some View {
        HStack {
            GlassButton(text: "Sleep", action: { isShowingSleepTimer = true })
                .accessibilityLabel("Sleep timer")
                .accessibilityHint("Opens sleep timer options")
            
            Spacer()
            
            GlassButton(text: String(format: "%.1fx", audioPlayerService.playbackRate), action: { isShowingSpeedOptions = true })
                .accessibilityLabel("Playback speed \(String(format: "%.1f", audioPlayerService.playbackRate)) times")
                .accessibilityHint("Opens playback speed options")
        }
        .frame(width: 252)
    }
    
    // MARK: - Computed Properties
    
    private var progressWidth: CGFloat {
        guard audioPlayerService.duration > 0 else { return 12 }
        let progress = audioPlayerService.currentTime / audioPlayerService.duration
        return max(12, 311 * progress) // Use 311 as default width (343 - 32 padding)
    }
    
    private func progressWidthForGeometry(_ geometry: GeometryProxy) -> CGFloat {
        guard audioPlayerService.duration > 0 else { return 12 }
        let progress = audioPlayerService.currentTime / audioPlayerService.duration
        return max(12, geometry.size.width * progress)
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
                withAnimation(.spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0.5)) {
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
    let accessibilityLabel: String?
    let accessibilityHint: String?
    
    init(systemIcon: String, size: CGFloat = 80, accessibilityLabel: String? = nil, accessibilityHint: String? = nil, action: @escaping () -> Void) {
        self.systemIcon = systemIcon
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                glassMorphismBackground
                iconView
            }
        }
        .frame(width: size, height: size)
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityLabel ?? defaultAccessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
    }
    
    private var glassMorphismBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
    
    private var iconView: some View {
        Image(systemName: systemIcon)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
    }
    
    private var iconSize: CGFloat {
        size * 0.24 // Scale icon relative to button size
    }
    
    private var defaultAccessibilityLabel: String {
        switch systemIcon {
        case "play.fill": return "Play"
        case "pause": return "Pause"
        case "gobackward.15": return "Rewind 15 seconds"
        case "goforward.15": return "Fast forward 15 seconds"
        default: return "Button"
        }
    }
}

// MARK: - Accessible Expanded Player Wrapper

struct AccessibleExpandedPlayer<Content: View>: View {
    let content: Content
    let onEscape: () -> Void
    
    init(@ViewBuilder content: () -> Content, onEscape: @escaping () -> Void) {
        self.content = content()
        self.onEscape = onEscape
    }
    
    var body: some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Minimize player") {
                onEscape()
            }
    }
}

// MARK: - Simplified Glass Button

struct GlassButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(glassBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    SlideUpPlayerView()
        .environmentObject(AudioPlayerService())
        .environmentObject(AccessibilityManager())
        .background(Color.black)
}
