//
//  SlideUpPlayerView.swift
//  FireVox
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
    @Environment(\.appTheme) var appTheme
    
    @State private var playerState: PlayerState = .minimized
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingSpeedOptions = false
    @State private var isShowingSleepTimer = false
    @State private var isShowingPlaylist = false
    @State private var isShowingGroupFiles = false
    @State private var screenWidth: CGFloat = 0
    
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
                                    .fill(appTheme.backgroundColor)
                                    .shadow(color: appTheme.shadowColor, radius: 15, x: 0, y: -2)
                            } else {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(.regularMaterial)
                                    .shadow(color: appTheme.shadowColor, radius: 15, x: 0, y: -2)
                            }
                        }
                    )
                    .gesture(dragGesture)
            }
            .onAppear {
                screenWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { oldValue, newValue in
                screenWidth = newValue
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .sheet(isPresented: $isShowingSleepTimer) {
            SleepTimerView()
        }
        .sheet(isPresented: $isShowingPlaylist) {
            PlaylistView()
        }
        .sheet(isPresented: $isShowingGroupFiles) {
            if audioPlayerService.isPlayingFromGroup && !audioPlayerService.groupedFilesQueue.isEmpty {
                GroupFilesListView(files: audioPlayerService.groupedFilesQueue, currentIndex: audioPlayerService.currentGroupedFileIndex)
            }
        }
        .sheet(isPresented: $isShowingSpeedOptions) {
            speedDialogButtons
                //.presentationDetents([.height(300)]) // Partial height
                .presentationDragIndicator(.visible)
        }
        .onChange(of: audioPlayerService.currentTime) { oldValue, newValue in
            // Only update if significant change (reduce excessive UI updates)
            if abs(newValue - oldValue) >= 1.0 {
                throttleUIUpdates()
            }
        }
        .onChange(of: audioPlayerService.folderCurrentTime) { oldValue, newValue in
            // Only update for folder progress if significant change
            if abs(newValue - oldValue) >= 1.0 {
                throttleUIUpdates()
            }
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
        VStack(spacing: 12) {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button {
                    audioPlayerService.setPlaybackRate(speed)
                    accessibilityManager.announceMessage("Playback speed set to \(speed)x")
                    isShowingSpeedOptions = false // Dismiss after selection
                } label: {
                    Text("\(speed, specifier: "%.2g")x")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appTheme.buttonBackgroundColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
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
            // Drag handle - chevron up
            Image(systemName: "chevron.up")
                .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 18))
                .foregroundColor(appTheme.textColor.opacity(0.5))
                .frame(height: 44)
                .accessibilityHidden(true)
            
            HStack(spacing: 12) {
                // Progress bar (takes most space)
                progressBarMinimized
                    .frame(height: 44)
                    .animation(.linear(duration: 0.3), value: progressWidthMinimized)
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
            VStack() {
                // Drag handle at top - now with gesture
                expandedPlayerDragHandle
                
                // Main content with adaptive spacing
                VStack(spacing: 24) {
                    // Book artwork with overlay details
                    artworkBackground
                        .frame(width: 280, height: 280)
                    
                    // Group files indicator (for audiobooks)
                    if audioPlayerService.isPlayingFromGroup && !audioPlayerService.groupedFilesQueue.isEmpty {
                        groupFilesIndicator
                    }
                    
                    // Book Details
                    bookDetailsOverlay
                    // Playback controls group
                    playbackControlsGroup
                    
                    // Control buttons
                    controlButtons
                    
                    // Bottom options (Sleep/Speed)
                    bottomOptions
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(appTheme.backgroundColor)
        }
        onEscape: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                playerState = .minimized
                accessibilityManager.announceMessage("Player minimized")
            }
        }
    }

    
    private var expandedPlayerDragHandle: some View {
        Image(systemName: "chevron.down")
            .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 18))
            .foregroundColor(appTheme.textColor.opacity(0.5))
            .frame(height: 44)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.height
                        dragOffset = translation
                    }
                    .onEnded { value in
                        let translation = value.translation.height
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0.5)) {
                            // Minimize if dragged down
                            if translation > 50 {
                                playerState = .minimized
                            }
                        }
                        dragOffset = 0
                    }
            )
    }
    
    
    private var artworkBackground: some View {
        let artworkURL = audioPlayerService.currentAudioFile?.artworkURL
        
        return RoundedRectangle(cornerRadius: 0)
            .fill(appTheme.secondaryBackgroundColor)
            .overlay(
                Group {
                    if let artworkURL = artworkURL {
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
                                    .font(FontManager.font(.regular, size: 80))
                                    .foregroundColor(appTheme.secondaryTextColor))
                            case .empty:
                                return AnyView(ProgressView()
                                    .scaleEffect(1.2))
                            }
                        }
                        .id(audioPlayerService.currentAudioFile?.id) // Force reload when file changes
                    } else {
                        Image(systemName: "music.note")
                            .font(FontManager.font(.regular, size: 80))
                            .foregroundColor(appTheme.secondaryTextColor)
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
                .init(color: appTheme.backgroundColor.opacity(0.7), location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
    
    private var bookDetailsOverlay: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(audioPlayerService.currentAudioFile?.title ?? "Title Long One Line Second")
                .font(FontManager.font(.regular, size: 20))
                .foregroundColor(appTheme.textColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text(audioPlayerService.currentAudioFile?.artist ?? "Author Name Long One")
                .font(FontManager.font(.regular, size: 17))
                .foregroundColor(appTheme.textColor.opacity(0.8))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private var playbackControlsGroup: some View {
        VStack(spacing: 0) {
            // Timestamps (folder-aware)
            HStack {
                Text(formatTime(displayCurrentTime))
                    .font(FontManager.font(.regular, size: 17))
                    .foregroundColor(appTheme.textColor)
                    .accessibilityLabel("Current time \(formatTimeForAccessibility(displayCurrentTime))")
                    .accessibilityHint("Drag to seek")
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Calculate new time based on drag offset
                                // 1 point of drag = 0.5 seconds of audio
                                let dragAmount = value.translation.width
                                let timeOffset = dragAmount * 0.5
                                let newTime = max(0, min(displayCurrentTime + timeOffset, displayTotalDuration))
                                audioPlayerService.seek(to: newTime)
                            }
                    )
                
                Spacer()
                
                Text(formatTime(displayTotalDuration))
                    .font(FontManager.font(.regular, size: 17))
                    .foregroundColor(appTheme.textColor)
                    .accessibilityLabel("Total duration \(formatTimeForAccessibility(displayTotalDuration))")
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
            
            // Slider area
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(appTheme.textColor.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress track (invisible, just for positioning)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.clear)
                        .frame(width: progressWidthForGeometry(geometry), height: 6)
                    
                    // Knob
                    Circle()
                        .fill(appTheme.textColor)
                        .frame(width: 24, height: 24)
                        .shadow(color: appTheme.shadowColor.opacity(0.12), radius: 2, x: 0, y: 0.5)
                        .shadow(color: appTheme.shadowColor.opacity(0.12), radius: 6.5, x: 0, y: 6)
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
        guard displayTotalDuration > 0 else {
            return "No duration information"
        }
        
        let remaining = displayTotalDuration - displayCurrentTime
        let remainingFormatted = formatTimeForAccessibility(remaining)
        let currentFormatted = formatTimeForAccessibility(displayCurrentTime)
        let durationFormatted = formatTimeForAccessibility(displayTotalDuration)
        
        let context = audioPlayerService.isPlayingFromFolder ? " in folder" : ""
        return "\(currentFormatted) of \(durationFormatted)\(context), \(remainingFormatted) remaining"
    }
    
    private var timelineAccessibilityValue: String {
        let currentFormatted = formatTimeForAccessibility(displayCurrentTime)
        let durationFormatted = formatTimeForAccessibility(displayTotalDuration)
        let context = audioPlayerService.isPlayingFromFolder ? " folder progress" : ""
        return "\(currentFormatted) of \(durationFormatted)\(context)"
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

    
    private var progressBarMinimized: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(appTheme.textColor.opacity(0.2))
                .frame(height: 6)
            
            RoundedRectangle(cornerRadius: 3)
                .fill(appTheme.accentColor)
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
    
    private var groupFilesIndicator: some View {
        let currentNum = audioPlayerService.currentGroupedFileIndex + 1
        let totalNum = audioPlayerService.groupedFilesQueue.count
        let playingText = "Playing \(currentNum) of \(totalNum)"
        
        return Button(action: { isShowingGroupFiles = true }) {
            HStack() {
                
                Text(playingText)
                    .font(FontManager.font(.regular, size: 16))
                                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(appTheme.textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(appTheme.textColor.opacity(0.15))
            .cornerRadius(12)
        }
        .accessibilityLabel("Audiobook files")
        .accessibilityValue("Playing file \(currentNum) of \(totalNum)")
        .accessibilityHint("Open list of all files in this audiobook")
    }
    
    // MARK: - Computed Properties
    
    // Folder-aware display properties
    private var displayCurrentTime: Double {
        if audioPlayerService.isPlayingFromFolder && audioPlayerService.folderTotalDuration > 0 {
            return audioPlayerService.folderCurrentTime
        }
        return audioPlayerService.currentTime
    }
    
    private var displayTotalDuration: Double {
        if audioPlayerService.isPlayingFromFolder && audioPlayerService.folderTotalDuration > 0 {
            return audioPlayerService.folderTotalDuration
        }
        return audioPlayerService.duration
    }
    
    private var displayProgress: Double {
        guard displayTotalDuration > 0 else { return 0 }
        return displayCurrentTime / displayTotalDuration
    }
    
    private var progressWidth: CGFloat {
        guard displayTotalDuration > 0 else { return 12 }
        return max(12, 311 * displayProgress) // Use 311 as default width (343 - 32 padding)
    }
    
    private func progressWidthForGeometry(_ geometry: GeometryProxy) -> CGFloat {
        guard displayTotalDuration > 0 else { return 12 }
        return max(12, geometry.size.width * displayProgress)
    }
    
    private var progressWidthMinimized: CGFloat {
        guard displayTotalDuration > 0 else { return 6 }
        let availableWidth = screenWidth - (16 + 16 + 64 + 12) // left padding + right padding + button width + spacing
        return max(6, max(0, availableWidth) * displayProgress)
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
    @Environment(\.appTheme) var appTheme
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
                    .stroke(appTheme.textColor.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: appTheme.shadowColor.opacity(0.15), radius: 12, x: 0, y: 6)
    }
    
    private var iconView: some View {
        Image(systemName: systemIcon)
            .font(FontManager.fontWithSystemFallback(weight: .semibold, size: iconSize))
            .foregroundColor(appTheme.textColor.opacity(0.9))
            .shadow(color: appTheme.shadowColor.opacity(0.3), radius: 1, x: 0, y: 1)
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
    @Environment(\.appTheme) var appTheme
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(text)
                    .font(FontManager.fontWithSystemFallback(weight: .semibold, size: 18))
                    .foregroundColor(appTheme.textColor)
                Image(systemName: "chevron.down")
                    .font(FontManager.fontWithSystemFallback(weight: .medium, size: 12))
                    .foregroundColor(appTheme.textColor.opacity(0.8))
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
                    .stroke(appTheme.textColor.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: appTheme.shadowColor.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    SlideUpPlayerView()
        .environmentObject(AudioPlayerService())
        .environmentObject(AccessibilityManager())
        .background(AppTheme(isDark: true).backgroundColor)
}
