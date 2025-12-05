//
//  MediaControlsManager.swift
//  AudioPlayer
//
//  Handles all Control Center and lock screen media widget display
//

import Foundation
import MediaPlayer
import AVFoundation
import UIKit

/// Manages Control Center and lock screen media widget display
/// - Centralizes all MPNowPlayingInfoCenter and MPRemoteCommandCenter logic
/// - Ensures consistent state across different playback contexts
/// - Provides clean interface for updating media metadata
class MediaControlsManager {
    
    // MARK: - Singleton
    static let shared = MediaControlsManager()
    
    // MARK: - Private Properties
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
    private var isCommandsSetup = false
    
    // MARK: - Public Properties
    var isMediaControlsAvailable: Bool {
        nowPlayingCenter.nowPlayingInfo != nil
    }
    
    // MARK: - Initialization
    private init() {
        setupRemoteCommands()
    }
    
    // MARK: - Setup Methods
    
    /// Initializes and configures all remote commands
    /// Should be called once during app setup
    private func setupRemoteCommands() {
        guard !isCommandsSetup else { return }
        
        print("🎵 [MediaControls] Setting up remote commands...")
        
        // Disable all commands first
        disableAllCommands()
        
        // Configure play command
        setupPlayCommand()
        
        // Configure pause command
        setupPauseCommand()
        
        // Configure toggle play/pause (for lock screen tap)
        setupTogglePlayPauseCommand()
        
        // Configure skip commands
        setupSkipCommands()
        
        // Configure track navigation
        setupTrackNavigation()
        
        // Configure playback position seeking
        setupPlaybackPositioning()
        
        isCommandsSetup = true
        print("✅ [MediaControls] All remote commands configured")
    }
    
    // MARK: - Command Setup Helpers
    
    private func disableAllCommands() {
        let commands = [
            commandCenter.playCommand,
            commandCenter.pauseCommand,
            commandCenter.togglePlayPauseCommand,
            commandCenter.skipForwardCommand,
            commandCenter.skipBackwardCommand,
            commandCenter.nextTrackCommand,
            commandCenter.previousTrackCommand,
            commandCenter.changePlaybackPositionCommand
        ]
        
        commands.forEach { command in
            command.removeTarget(nil)
            command.isEnabled = false
        }
    }
    
    private func setupPlayCommand() {
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            print("▶️ [MediaControls] Play command received")
            self?.handleCommand { $0.handlePlayCommand() }
            return .success
        }
    }
    
    private func setupPauseCommand() {
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            print("⏸️ [MediaControls] Pause command received")
            self?.handleCommand { $0.handlePauseCommand() }
            return .success
        }
    }
    
    private func setupTogglePlayPauseCommand() {
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            print("🔄 [MediaControls] Toggle play/pause received (lock screen)")
            self?.handleCommand { $0.handleTogglePlayPauseCommand() }
            return .success
        }
    }
    
    private func setupSkipCommands() {
        // Skip forward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            print("⏩ [MediaControls] Skip forward 15s received")
            self?.handleCommand { $0.handleSkipForwardCommand() }
            return .success
        }
        
        // Skip backward
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            print("⏪ [MediaControls] Skip backward 15s received")
            self?.handleCommand { $0.handleSkipBackwardCommand() }
            return .success
        }
    }
    
    private func setupTrackNavigation() {
        // Next track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            print("⏭️ [MediaControls] Next track received")
            self?.handleCommand { $0.handleNextTrackCommand() }
            return .success
        }
        
        // Previous track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            print("⏮️ [MediaControls] Previous track received")
            self?.handleCommand { $0.handlePreviousTrackCommand() }
            return .success
        }
    }
    
    private func setupPlaybackPositioning() {
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            print("📍 [MediaControls] Playback position seek to \\(positionEvent.positionTime)s")
            self?.handleCommand { $0.handlePlaybackPositionChange(to: positionEvent.positionTime) }
            return .success
        }
    }
    
    // MARK: - Command Handler
    
    private func handleCommand(_ action: @escaping (MediaControlsDelegate) -> Void) {
        // Get delegate from shared audio player service
        guard let delegate = MediaControlsManager.delegate else {
            print("⚠️ [MediaControls] No delegate set for handling commands")
            return
        }
        
        // Dispatch to main thread for thread safety
        DispatchQueue.main.async {
            action(delegate)
        }
    }
    
    // MARK: - Delegate (Weak Reference)
    
    private static weak var delegate: MediaControlsDelegate?
    
    /// Sets the delegate that handles media control commands
    static func setDelegate(_ delegate: MediaControlsDelegate) {
        MediaControlsManager.delegate = delegate
    }
    
    // MARK: - Media Info Updates
    
    /// Updates the Now Playing information displayed in Control Center and lock screen
    /// - Parameters:
    ///   - title: Track title
    ///   - artist: Artist name
    ///   - album: Album name
    ///   - duration: Track duration in seconds
    ///   - currentTime: Current playback position in seconds
    ///   - isPlaying: Whether audio is currently playing
    ///   - playbackRate: Current playback speed (1.0 = normal)
    ///   - artwork: Optional artwork image
    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String,
        duration: Double,
        currentTime: Double,
        isPlaying: Bool,
        playbackRate: Double,
        artwork: UIImage? = nil
    ) {
        // Validate essential values
        guard duration > 0 else {
            print("⚠️ [MediaControls] Cannot update Now Playing with invalid duration: \\(duration)")
            return
        }
        
        print("🎵 [MediaControls] Updating Now Playing: \\(title) - \\(artist)")
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0,
            MPMediaItemPropertyMediaType: MPMediaType.music.rawValue
        ]
        
        // Add artwork if provided
        if let artwork = artwork {
            let mediaArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
            print("🖼️ [MediaControls] Artwork added")
        }
        
        // Set to Now Playing center
        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        
        // Verify update
        if nowPlayingCenter.nowPlayingInfo != nil {
            print("✅ [MediaControls] Now Playing info updated successfully")
        } else {
            print("❌ [MediaControls] Failed to update Now Playing info")
        }
    }
    
    /// Clears the Now Playing information
    func clearNowPlayingInfo() {
        print("🔄 [MediaControls] Clearing Now Playing info")
        nowPlayingCenter.nowPlayingInfo = nil
    }
    
    // MARK: - State Management
    
    /// Ensures audio session is properly configured for media controls
    func ensureAudioSessionActive() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set category and activate
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
            
            print("✅ [MediaControls] Audio session configured and active")
        } catch {
            print("❌ [MediaControls] Failed to configure audio session: \\(error)")
        }
    }
}

// MARK: - Delegate Protocol

/// Protocol for handling media control commands
protocol MediaControlsDelegate: AnyObject {
    func handlePlayCommand()
    func handlePauseCommand()
    func handleTogglePlayPauseCommand()
    func handleSkipForwardCommand()
    func handleSkipBackwardCommand()
    func handleNextTrackCommand()
    func handlePreviousTrackCommand()
    func handlePlaybackPositionChange(to position: Double)
}
