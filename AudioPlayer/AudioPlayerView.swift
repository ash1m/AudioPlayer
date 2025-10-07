//
//  AudioPlayerView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
/*

import SwiftUI
import CoreData

struct AudioPlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State private var isShowingSpeedOptions = false
    @State private var lastAnnouncedTime: Double = 0
    @State private var isShowingSleepTimer = false
    
    // MARK: - Computed Properties
    private var progressAccessibilityValue: String {
        let current = TimeInterval(audioPlayerService.currentTime).accessibleDuration
        let total = TimeInterval(audioPlayerService.duration).accessibleDuration
        let remaining = TimeInterval(audioPlayerService.duration - audioPlayerService.currentTime).accessibleDuration
        
        if audioPlayerService.duration > 0 {
            let percentage = Int((audioPlayerService.currentTime / audioPlayerService.duration) * 100)
            return "\(percentage)%, \(current) of \(total), \(remaining) remaining"
        } else {
            return "No audio loaded"
        }
    }
    
    private var timeDisplayAccessibilityLabel: String {
        let current = TimeInterval(audioPlayerService.currentTime).accessibleDuration
        let total = TimeInterval(audioPlayerService.duration).accessibleDuration
        return "Current position: \(current) of \(total)"
    }
    
    private var playPauseAccessibilityLabel: String {
        let baseLabel = audioPlayerService.isPlaying ? "Pause" : "Play"
        if let title = audioPlayerService.currentAudioFile?.title {
            return "\(baseLabel) \(title)"
        }
        return baseLabel
    }
    
    private var playPauseAccessibilityHint: String {
        if audioPlayerService.isPlaying {
            return "Double tap to pause the current audio"
        } else if audioPlayerService.currentAudioFile != nil {
            return "Double tap to resume playback"
        } else {
            return "No audio file selected"
        }
    }
    
    private var playPauseAccessibilityValue: String {
        let statusText = audioPlayerService.isPlaying ? "Playing" : "Paused"
        if let audioFile = audioPlayerService.currentAudioFile {
            return "\(statusText): \(audioFile.title ?? "Unknown title")"
        }
        return statusText
    }
    
    private var playbackSpeedAccessibilityValue: String {
        let speed = audioPlayerService.playbackRate
        if speed == 1.0 {
            return "Normal speed"
        } else {
            return String(format: "%.1f times speed", speed)
        }
    }
    
    private var sleepTimerAccessibilityLabel: String {
        return accessibilityManager.sleepTimerActive ? "Sleep timer active" : "Sleep timer"
    }
    
    private var sleepTimerAccessibilityValue: String {
        if accessibilityManager.sleepTimerActive {
            let minutes = Int(accessibilityManager.sleepTimerRemaining / 60)
            let seconds = Int(accessibilityManager.sleepTimerRemaining.truncatingRemainder(dividingBy: 60))
            if minutes > 0 {
                return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s") remaining"
            } else {
                return "\(seconds) second\(seconds == 1 ? "" : "s") remaining"
            }
        } else {
            return "Not set"
        }
    }
    
    // MARK: - View Components
/*    private var albumArtView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 224, height: 224)
            
            if let artworkURL = audioPlayerService.currentAudioFile?.artworkURL {
                LocalAsyncImageWithPhase(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        return AnyView(image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 224, height: 224)
                            .clipShape(RoundedRectangle(cornerRadius: 20)))
                    case .failure(let error):
                        let _ = print("🎨 LocalAsyncImage (player) failed to load artwork: \(error)")
                        return AnyView(Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white))
                    case .empty:
                        return AnyView(ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2))
                    }
                }
                .accessibilityLabel("Album artwork")
                .accessibilityHidden(true)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .accessibilityLabel("Album artwork")
                    .accessibilityHidden(true)
            }
        }
    }*/
    
/*    private var songInfoView: some View {
        VStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
            Text(audioPlayerService.currentAudioFile?.title ?? "No Song Selected")
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Currently playing: \(audioPlayerService.currentAudioFile?.title ?? "No Song Selected")")
                .visualAccessibility()
            
            Text(audioPlayerService.currentAudioFile?.artist ?? "Unknown Artist")
                .font(.subheadline)
                .accessibilityLabel("Artist: \(audioPlayerService.currentAudioFile?.artist ?? "Unknown Artist")")
                .visualAccessibility()
        }
        .accessiblePadding(.horizontal, dynamicTypeSize: dynamicTypeSize)
        .padding(.vertical, AccessibleSpacing.standard(for: dynamicTypeSize))
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(accessibilityManager.isReduceTransparencyEnabled ? 0.3 : 0.2))
        )
        .accessibilityElement(children: .combine)
    }
 
    private var progressSliderView: some View {
        VStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
            Slider(value: Binding(
                get: { audioPlayerService.currentTime },
                set: { newValue in 
                    audioPlayerService.seek(to: newValue)
                    if accessibilityManager.isVoiceOverRunning {
                        let currentFormatted = TimeInterval(newValue).accessibleDuration
                        let totalFormatted = TimeInterval(audioPlayerService.duration).accessibleDuration
                        accessibilityManager.announceMessage("\(currentFormatted) of \(totalFormatted)")
                    }
                }
            ), in: 0...max(audioPlayerService.duration, 1))
                .scaleEffect(0.9)
                .accentColor(.blue)
                .accessibilityLabel("Playback progress")
                .accessibilityValue(progressAccessibilityValue)
                .accessibilityHint("Use swipe up or down to adjust playback position. Double tap and hold to scrub through the audio.")
                .accessibilityAdjustableAction { direction in
                    let increment: Double = 15
                    let newTime = direction == .increment ? 
                        min(audioPlayerService.currentTime + increment, audioPlayerService.duration) :
                        max(audioPlayerService.currentTime - increment, 0)
                    audioPlayerService.seek(to: newTime)
                    
                    let currentFormatted = TimeInterval(newTime).accessibleDuration
                    let totalFormatted = TimeInterval(audioPlayerService.duration).accessibleDuration
                    let action = direction == .increment ? "Skipped forward to" : "Skipped back to"
                    accessibilityManager.announceMessage("\(action) \(currentFormatted) of \(totalFormatted)")
                }
            
            HStack {
                Text("\(TimeInterval(audioPlayerService.currentTime).formattedDuration) / \(TimeInterval(audioPlayerService.duration).formattedDuration)")
                    .systemFontWithWeight(.regular, size: .caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(timeDisplayAccessibilityLabel)
                    .visualAccessibility(foreground: .secondary)
                
                Spacer()
            }
            .accessibilityElement(children: .combine)
        }
        .accessiblePadding(.horizontal, dynamicTypeSize: dynamicTypeSize)
    }
    */
    private var playbackControlsView: some View {
        HStack(spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
            Button(action: {
                audioPlayerService.rewind15()
                accessibilityManager.announceSkip(direction: "backward", seconds: 15)
            }) {
                Image(systemName: "gobackward.15")
                    .font(dynamicTypeSize.isLargeSize ? .title2 : .title)
                    .foregroundColor(.primary)
            }
            .accessibilityLabel("Skip backward")
            .accessibilityHint("Double tap to skip backward 15 seconds")
            .accessibilityAddTraits(.isButton)
            .accessibilityValue("15 seconds")
            .accessibleTouchTarget()
            .visualAccessibility()
            
            Button(action: {
                let wasPlaying = audioPlayerService.isPlaying
                audioPlayerService.togglePlayback()
                let title = audioPlayerService.currentAudioFile?.title
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    accessibilityManager.announcePlaybackChange(isPlaying: !wasPlaying, title: title)
                }
            }) {
                Image(systemName: audioPlayerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: dynamicTypeSize.isLargeSize ? 50 : 60))
                    .foregroundColor(.accentColor)
            }
            .accessibilityLabel(playPauseAccessibilityLabel)
            .accessibilityHint(playPauseAccessibilityHint)
            .accessibilityAddTraits([.isButton, .playsSound])
            .accessibilityValue(playPauseAccessibilityValue)
            .accessibleTouchTarget(minSize: CGSize(width: 60, height: 60))
            .highContrastSupport(normal: .accentColor, highContrast: .primary)
            
            Button(action: {
                audioPlayerService.fastForward15()
                accessibilityManager.announceSkip(direction: "forward", seconds: 15)
            }) {
                Image(systemName: "goforward.15")
                    .font(dynamicTypeSize.isLargeSize ? .title2 : .title)
                    .foregroundColor(.primary)
            }
            .accessibilityLabel("Skip forward")
            .accessibilityHint("Double tap to skip forward 15 seconds")
            .accessibilityAddTraits(.isButton)
            .accessibilityValue("15 seconds")
            .accessibleTouchTarget()
            .visualAccessibility()
        }
    }
    
    private var sleepTimerButton: some View {
        Button(action: { isShowingSleepTimer = true }) {
            HStack(spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                Image(systemName: accessibilityManager.sleepTimerActive ? "moon.zzz.fill" : "moon.zzz")
                    .font(.caption)
                if accessibilityManager.sleepTimerActive {
                    Text("\(Int(accessibilityManager.sleepTimerRemaining / 60))m")
                        .systemFontWithWeight(.regular, size: .caption2)
                }
            }
            .padding(.horizontal, AccessibleSpacing.compact(for: dynamicTypeSize))
            .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
            .background(
                Color.black.opacity(accessibilityManager.isReduceTransparencyEnabled ? 0.3 : 0.2)
            )
            .cornerRadius(15)
        }
        .accessibilityLabel(sleepTimerAccessibilityLabel)
        .accessibilityValue(sleepTimerAccessibilityValue)
        .accessibilityHint("Double tap to set or manage sleep timer")
        .accessibilityAddTraits(.isButton)
        .accessibleTouchTarget()
        .visualAccessibility()
    }
    
    private var speedButton: some View {
        Button(action: { isShowingSpeedOptions.toggle() }) {
            Text("\(audioPlayerService.playbackRate, specifier: "%.1f")x")
                .systemFontWithWeight(.medium, size: .controlLabel)
                .padding(.horizontal, AccessibleSpacing.standard(for: dynamicTypeSize))
                .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
                .background(
                    Color.black.opacity(accessibilityManager.isReduceTransparencyEnabled ? 0.3 : 0.2)
                )
                .cornerRadius(15)
        }
        .accessibilityLabel("Playback speed")
        .accessibilityValue(playbackSpeedAccessibilityValue)
        .accessibilityHint("Double tap to change playback speed. Current options include 0.5x, 0.75x, 1x, 1.25x, 1.5x, and 2x speed.")
        .accessibilityAddTraits(.isButton)
        .accessibleTouchTarget()
        .visualAccessibility()
    }
    
    private var speedAndTimerControlsView: some View {
        HStack {
            sleepTimerButton
            Spacer()
            speedButton
        }
        .accessiblePadding(.horizontal, dynamicTypeSize: dynamicTypeSize)
    }
    
    private var mainContentView: some View {
        ZStack {
            // Background image
            Image("player-background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea(.all)
                .accessibilityHidden(true)
            
            // Dark overlay for better readability
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(.all)
                .accessibilityHidden(true)
            
            VStack(spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
                Spacer()
                
                // Album Art
               // albumArtView
                
                // Song Info
                //songInfoView
                
                // Progress Slider
                //progressSliderView
                
                // Playback Controls
                playbackControlsView
                
                // Speed Control and Sleep Timer
                speedAndTimerControlsView
                
                Spacer()
            }
            .padding(.top, 75)
        }
    }
    
    private var navigationView: some View {
        NavigationStack {
            mainContentView
                .navigationTitle("Now Playing")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private var speedDialogButtons: some View {
        Button("0.5x") {
            audioPlayerService.setPlaybackRate(0.5)
            accessibilityManager.announceMessage("Playback speed set to 0.5x speed")
        }
        .accessibilityLabel("0.5x speed")
        .accessibilityHint("Double tap to set playback speed")
        
        Button("0.75x") {
            audioPlayerService.setPlaybackRate(0.75)
            accessibilityManager.announceMessage("Playback speed set to 0.75x speed")
        }
        .accessibilityLabel("0.75x speed")
        .accessibilityHint("Double tap to set playback speed")
        
        Button("1.0x") {
            audioPlayerService.setPlaybackRate(1.0)
            accessibilityManager.announceMessage("Playback speed set to normal speed")
        }
        .accessibilityLabel("Normal speed")
        .accessibilityHint("Double tap to set playback speed")
        
        Button("1.25x") {
            audioPlayerService.setPlaybackRate(1.25)
            accessibilityManager.announceMessage("Playback speed set to 1.25x speed")
        }
        .accessibilityLabel("1.25x speed")
        .accessibilityHint("Double tap to set playback speed")
        
        Button("1.5x") {
            audioPlayerService.setPlaybackRate(1.5)
            accessibilityManager.announceMessage("Playback speed set to 1.5x speed")
        }
        .accessibilityLabel("1.5x speed")
        .accessibilityHint("Double tap to set playback speed")
        
        Button("2.0x") {
            audioPlayerService.setPlaybackRate(2.0)
            accessibilityManager.announceMessage("Playback speed set to 2x speed")
        }
        .accessibilityLabel("2x speed")
        .accessibilityHint("Double tap to set playback speed")
        
        Button("Cancel", role: .cancel) { }
    }
    
    private var viewWithModifiers: some View {
        navigationView
            .onReceive(NotificationCenter.default.publisher(for: .sleepTimerExpired)) { _ in
                audioPlayerService.pause()
            }
            .onAppear {
                accessibilityManager.announceScreenChange()
                if let audioFile = audioPlayerService.currentAudioFile {
                    let announcement = "Now playing: \(audioFile.title ?? "Unknown title") by \(audioFile.artist ?? "Unknown artist")"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        accessibilityManager.announceMessage(announcement)
                    }
                }
            }
            .sheet(isPresented: $isShowingSleepTimer) {
                SleepTimerView()
            }
            .confirmationDialog("Playback Speed", isPresented: $isShowingSpeedOptions, titleVisibility: .visible) {
                speedDialogButtons
            }
    }
    
    var body: some View {
        viewWithModifiers
    }
}

#Preview {
    AudioPlayerView()
        .environmentObject(AudioPlayerService())
        .environmentObject(AudioFileManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
*/
