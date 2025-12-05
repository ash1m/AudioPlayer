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
        guard !isCommandsSetup else { 
            print("[MediaControls] Remote commands already setup, skipping...")
            return 
        }
        
        print("\n🎵 [MediaControls] ========== INITIALIZING MEDIA CONTROLS ==========")
        print("   Setting up MPRemoteCommandCenter...")
        
        // Disable all commands first
        disableAllCommands()
        print("   ✅ All previous command targets cleared")
        
        // Configure play command
        setupPlayCommand()
        print("   ✅ Play command configured")
        
        // Configure pause command
        setupPauseCommand()
        print("   ✅ Pause command configured")
        
        // Configure toggle play/pause (for lock screen tap)
        setupTogglePlayPauseCommand()
        print("   ✅ Toggle Play/Pause command configured (lock screen)")
        
        // Configure skip commands
        setupSkipCommands()
        print("   ✅ Skip Forward/Backward commands configured")
        
        // Configure track navigation
        setupTrackNavigation()
        print("   ✅ Next/Previous track commands configured")
        
        // Configure playback position seeking
        setupPlaybackPositioning()
        print("   ✅ Playback position seeking configured")
        
        isCommandsSetup = true
        print("\n✅ [MediaControls] All remote commands configured and ready")
        print("   Now Playing info updates will appear in:")
        print("   - Control Center")
        print("   - Lock screen media widget")
        print("   - Headphone controls")
        print("========================================\n")
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
            print("\n▶️ [MediaControls] ⚡ PLAY COMMAND RECEIVED FROM CONTROL CENTER/LOCK SCREEN ⚡")
            self?.handleCommand { $0.handlePlayCommand() }
            print("   ✅ Play command forwarded to audio player\n")
            return .success
        }
    }
    
    private func setupPauseCommand() {
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            print("\n⏸️ [MediaControls] ⚡ PAUSE COMMAND RECEIVED FROM CONTROL CENTER/LOCK SCREEN ⚡")
            self?.handleCommand { $0.handlePauseCommand() }
            print("   ✅ Pause command forwarded to audio player\n")
            return .success
        }
    }
    
    private func setupTogglePlayPauseCommand() {
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            print("\n🔄 [MediaControls] ⚡ TOGGLE PLAY/PAUSE RECEIVED FROM LOCK SCREEN TAP ⚡")
            self?.handleCommand { $0.handleTogglePlayPauseCommand() }
            print("   ✅ Toggle command forwarded to audio player\n")
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
        print("\n🔗 [MediaControls] Delegate registered: \(type(of: delegate))")
        print("   Remote commands will now be routed to: \(type(of: delegate))")
        print("   Control Center/Lock Screen interactions enabled\n")
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
            print("❌ [MediaControls] DIAGNOSTIC: Cannot update Now Playing with invalid duration: \(duration)")
            print("   Title: \(title)")
            print("   Artist: \(artist)")
            return
        }
        
        print("\n🎵 [MediaControls] ========== UPDATING NOW PLAYING INFO ==========")
        print("   Title: \(title)")
        print("   Artist: \(artist)")
        print("   Album: \(album)")
        print("   Duration: \(String(format: "%.2f", duration))s")
        print("   Current Time: \(String(format: "%.2f", currentTime))s")
        print("   Is Playing: \(isPlaying)")
        print("   Playback Rate: \(playbackRate)x")
        print("   Playback Rate (for CC): \(isPlaying ? playbackRate : 0.0)")
        print("   Has Artwork: \(artwork != nil)")
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0,
            MPMediaItemPropertyMediaType: MPMediaType.music.rawValue
        ]
        
        print("\n   Building Now Playing Dictionary with \(nowPlayingInfo.count) base properties...")
        
        // Add artwork if provided
        if let artwork = artwork {
            let mediaArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
            print("   ✅ Artwork added (\(Int(artwork.size.width))x\(Int(artwork.size.height))px)")
        } else {
            print("   ⚠️ No artwork provided")
        }
        
        // Set to Now Playing center
        print("\n   Setting to MPNowPlayingInfoCenter...")
        nowPlayingCenter.nowPlayingInfo = nowPlayingInfo
        
        // Verify update with detailed diagnostics
        if let verifiedInfo = nowPlayingCenter.nowPlayingInfo {
            print("   ✅ Now Playing info set successfully")
            print("   Verified properties: \(verifiedInfo.count)")
            print("   - Title: \(verifiedInfo[MPMediaItemPropertyTitle] as? String ?? "[missing]")")
            print("   - Artist: \(verifiedInfo[MPMediaItemPropertyArtist] as? String ?? "[missing]")")
            print("   - Album: \(verifiedInfo[MPMediaItemPropertyAlbumTitle] as? String ?? "[missing]")")
            print("   - Duration: \(verifiedInfo[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0)s")
            print("   - Elapsed: \(verifiedInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0)s")
            print("   - Rate: \(verifiedInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0)")
            print("   - Has Artwork: \(verifiedInfo[MPMediaItemPropertyArtwork] != nil)")
            print("   - Media Type: \(verifiedInfo[MPMediaItemPropertyMediaType] as? NSNumber ?? 0)")
            print("✅ [MediaControls] Control Center/Lock Screen should now display")
            print("========================================\n")
        } else {
            print("   ❌ DIAGNOSTIC: Failed to set Now Playing info")
            print("   MPNowPlayingInfoCenter.nowPlayingInfo is nil")
            print("   Control Center and lock screen will NOT display")
            print("========================================\n")
        }
    }
    
    /// Clears the Now Playing information
    func clearNowPlayingInfo() {
        print("\n🔄 [MediaControls] ========== CLEARING NOW PLAYING INFO ==========")
        if nowPlayingCenter.nowPlayingInfo != nil {
            print("   Clearing existing Now Playing info...")
            nowPlayingCenter.nowPlayingInfo = nil
            if nowPlayingCenter.nowPlayingInfo == nil {
                print("   ✅ Successfully cleared")
                print("   Control Center and lock screen will be HIDDEN")
            } else {
                print("   ❌ Failed to clear (unexpected)")
            }
        } else {
            print("   ⚠️ Now Playing info is already nil (nothing to clear)")
        }
        print("========================================\n")
    }
    
    // MARK: - State Management
    
    /// Ensures audio session is properly configured for media controls
    func ensureAudioSessionActive() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            print("\n🔧 [MediaControls] ========== AUDIO SESSION DIAGNOSTIC ==========")
            print("   Current category: \(audioSession.category)")
            print("   Current mode: \(audioSession.mode)")
            
            // Set category and activate
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            print("   ✅ Category set to: .playback")
            print("   ✅ Options set to: [.mixWithOthers]")
            
            try audioSession.setActive(true)
            print("   ✅ Audio session activated")
            
            print("   \nVerification:")
            print("   - Category: \(audioSession.category)")
            print("   - Mode: \(audioSession.mode)")
            print("   - Is Other Audio Playing: \(audioSession.isOtherAudioPlaying)")
            print("✅ [MediaControls] Audio session ready for Control Center/Lock Screen")
            print("========================================\n")
        } catch {
            print("\n❌ [MediaControls] ========== AUDIO SESSION ERROR ==========")
            print("   Failed to configure audio session")
            print("   Error: \(error.localizedDescription)")
            print("   IMPACT: Control Center may not appear")
            print("========================================\n")
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
