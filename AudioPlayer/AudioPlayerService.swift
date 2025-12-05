//
//  FireVoxService.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/15.
//

import Foundation
import AVFoundation
import MediaPlayer
import CoreData
import Combine
import UIKit

class AudioPlayerService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackRate: Double = 1.0
    @Published var currentAudioFile: AudioFile?
    @Published var isPlayingFromPlaylist = false
    @Published var continuousPlaybackEnabled = true
    
    // MARK: - Folder Progress Properties
    @Published var isPlayingFromFolder = false
    @Published var folderCurrentTime: Double = 0.0
    @Published var folderTotalDuration: Double = 0.0
    
    // Artwork versioning for UI refresh
    @Published var artworkVersion: Int = 0
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var viewContext: NSManagedObjectContext?
    private var isInBackground = false
    private var lastUpdateTime: CFTimeInterval = 0
    private var lastNowPlayingUpdateTime: Double = 0
    
    // MARK: - Playlist Queue Properties
    private var currentPlaylist: Playlist?
    private var currentPlaylistItemIndex: Int = 0
    private weak var playlistManager: PlaylistManager?
    
    // MARK: - Folder Playback Properties
    private var currentFolder: Folder?
    
    // MARK: - Grouped Files Playback Properties
    @Published var groupedFilesQueue: [AudioFile] = []
    @Published var currentGroupedFileIndex: Int = 0
    @Published var isPlayingFromGroup = false
    
    override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    deinit {
        removeTimeObserver()
        player?.pause()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSleepTimerExpired),
            name: .sleepTimerExpired,
            object: nil
        )
        
        // Background/foreground notifications for performance optimization
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // AVAudioSession interruption notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // AVAudioSession route change notifications (for bluetooth/headphone disconnect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleSleepTimerExpired() {
        pause()
    }
    
    @objc private func appDidEnterBackground() {
        isInBackground = true
        print("📱 App entered background - optimizing performance")
        
        // Significantly reduce update frequency in background to save battery
        if timeObserver != nil {
            removeTimeObserver()
            setupBackgroundTimeObserver()
        }
    }
    
    @objc private func appWillEnterForeground() {
        isInBackground = false
        print("📱 App entered foreground - resuming normal updates")
        
        // Resume normal update frequency when returning to foreground
        if timeObserver != nil {
            removeTimeObserver()
            setupTimeObserver()
        }
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio session was interrupted (phone call, other app, etc.)
            if isPlaying {
                DispatchQueue.main.async { [weak self] in
                    self?.isPlaying = false
                    self?.saveCurrentPosition()
                    print("🎵 Audio session interrupted - pausing playback")
                }
            }
            
        case .ended:
            // Audio session interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                // System suggests we should resume playback
                DispatchQueue.main.async { [weak self] in
                    // Re-setup audio session and remote controls after interruption
                    self?.setupAudioSession()
                    
                    // Only resume if we have a valid player and the interruption allows it
                    if self?.player != nil {
                        self?.play()
                        print("🎵 Audio session interruption ended - resuming playback")
                    }
                }
            } else {
                // Don't resume automatically, but make sure our state is correct
                DispatchQueue.main.async { [weak self] in
                    self?.isPlaying = false
                    print("🎵 Audio session interruption ended - not resuming playback")
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones/bluetooth device was disconnected
            DispatchQueue.main.async { [weak self] in
                if self?.isPlaying == true {
                    self?.pause()
                    print("🎵 Audio output device disconnected - pausing playback")
                }
            }
            
        case .newDeviceAvailable:
            // New audio device connected - don't auto-resume, just log
            print("🎵 New audio output device connected")
            
        default:
            break
        }
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            print("🔧 Setting up audio session for media controls...")
            
            // CRITICAL: Use specific options required for Control Center
            let sessionOptions: AVAudioSession.CategoryOptions = [
                .allowBluetoothA2DP,
                .allowAirPlay,
                .defaultToSpeaker,
                .mixWithOthers
            ]
            
            // Use .default mode instead of .spokenAudio for better Control Center integration
            try audioSession.setCategory(.playback, mode: .default, options: sessionOptions)
            print("✅ Audio session category set to .playback with Control Center options")
            
            // CRITICAL: Set the audio session active - this is required for Control Center
            try audioSession.setActive(true, options: [])
            print("✅ Audio session activated successfully")
            
            // Small delay to ensure audio session is fully established
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setupRemoteTransportControls()
                print("✅ Audio session and remote controls configured with delay")
            }
            
        } catch let error as NSError {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
            print("   Error domain: \(error.domain), code: \(error.code)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   Underlying error: \(underlyingError.localizedDescription)")
            }
            
            // Try alternative setup on failure
            setupFallbackAudioSession()
        }
    }
    
    private func setupFallbackAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            print("🔧 Attempting fallback audio session setup...")
            
            // Minimal configuration that should work
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            print("✅ Fallback audio session activated")
            setupRemoteTransportControls()
            
        } catch {
            print("❌ Fallback audio session setup also failed: \(error.localizedDescription)")
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        print("🎵 Setting up remote transport controls...")
        
        // Clear existing targets properly by storing references
        let commands = [
            commandCenter.playCommand,
            commandCenter.pauseCommand,
            commandCenter.skipForwardCommand,
            commandCenter.skipBackwardCommand,
            commandCenter.nextTrackCommand,
            commandCenter.previousTrackCommand,
            commandCenter.changePlaybackPositionCommand
        ]
        
        // Clear all existing targets
        commands.forEach { command in
            command.removeTarget(self)
            command.isEnabled = false
        }
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            print("▶️ Remote play command received")
            DispatchQueue.main.async {
                self?.play()
            }
            return .success
        }
        print("✅ Play command configured")
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            print("⏸️ Remote pause command received")
            DispatchQueue.main.async {
                self?.pause()
            }
            return .success
        }
        print("✅ Pause command configured")
        
        // Skip forward command (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.fastForward15()
            }
            return .success
        }
        
        // Skip backward command (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                self?.rewind15()
            }
            return .success
        }
        
        // Next track command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                let success = (self?.isPlayingFromPlaylist == true) ?
                    (self?.playNext() ?? false) :
                    (self?.playNextInFolder() ?? false)
                
                if !success {
                    // If no next track, just seek to end or restart current
                    self?.seek(to: self?.duration ?? 0)
                }
            }
            return .success
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                // If we're more than 3 seconds into the track, restart current track
                if (self?.currentTime ?? 0) > 3.0 {
                    self?.seek(to: 0)
                } else {
                    // Otherwise go to actual previous track
                    let success = (self?.isPlayingFromPlaylist == true) ?
                        (self?.playPrevious() ?? false) :
                        (self?.playPreviousInFolder() ?? false)
                    
                    if !success {
                        // If no previous track, restart current
                        self?.seek(to: 0)
                    }
                }
            }
            return .success
        }
        
        // Playback position command (seek bar)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            DispatchQueue.main.async {
                self?.seek(to: event.positionTime)
                self?.updateNowPlayingInfo()
            }
            return .success
        }
        
        print("✅ All remote transport controls configured")
        print("✅ Control Center and Lock Screen controls should now be available")
        
        // Don't set initial Now Playing info here - let it be set when audio actually loads
        // This prevents conflicts with actual playback information
        print("✅ Remote command center ready for Control Center activation")
    }
    
    // MARK: - Ensure Audio Session Active
    
    private func ensureAudioSessionAndRemoteControlsActive() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            print("🔍 Ensuring audio session is active for Control Center...")
            
            // Check if audio session is active and reactivate if needed
            if audioSession.category != .playback || !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
                print("✅ Audio session re-activated for playback")
            }
            
            // Don't re-setup remote controls unnecessarily - they should persist
            // Just ensure we have proper Now Playing info when we actually start playing
            print("✅ Audio session ensured active")
            
        } catch {
            print("⚠️ Warning: Could not ensure audio session active: \(error.localizedDescription)")
            // As a last resort, try full re-setup
            DispatchQueue.main.async { [weak self] in
                self?.setupAudioSession()
            }
        }
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo() {
        print("📱 updateNowPlayingInfo() called - Playing: \(isPlaying)")
        
        guard let audioFile = currentAudioFile else {
            print("⚠️ No current audio file, clearing Now Playing info")
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        // Get the most current time from the player if available
        let actualCurrentTime = player?.currentTime().seconds ?? currentTime
        
        let title = audioFile.title ?? (audioFile.fileName ?? "Unknown")
        print("🎵 Setting Now Playing info for: \(title)")
        print("🔊 Duration: \(duration), Actual Time: \(actualCurrentTime), Playing: \(isPlaying), Rate: \(playbackRate)")
        
        // Determine duration and elapsed time based on playback context
        var displayDuration: Double
        var displayElapsedTime: Double
        var displayAlbumTitle: String
        
        if isPlayingFromFolder, let folder = currentFolder, folderTotalDuration > 0 {
            // Use folder progress for Control Center - validate values
            displayDuration = max(folderTotalDuration, 0.1)  // Ensure positive duration
            displayElapsedTime = max(min(folderCurrentTime, folderTotalDuration), 0.0)  // Clamp within bounds
            let folderName = folder.name ?? "Folder"
            displayAlbumTitle = folderName.isEmpty ? "Folder" : folderName
            print("📁 Using folder progress in Now Playing - \(Int(displayElapsedTime))/\(Int(displayDuration))")
        } else {
            // Use individual file progress - validate values
            displayDuration = max(duration, 0.1)  // Ensure positive duration
            displayElapsedTime = max(min(actualCurrentTime, displayDuration), 0.0)  // Clamp within bounds
            displayAlbumTitle = (audioFile.album ?? "").isEmpty ? "AudioPlayer" : (audioFile.album ?? "AudioPlayer")
        }
        
        // Use more standard media type
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: (title as Any),
            MPMediaItemPropertyArtist: audioFile.artist ?? "Unknown Artist",
            MPMediaItemPropertyAlbumTitle: displayAlbumTitle,
            MPMediaItemPropertyPlaybackDuration: displayDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: displayElapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0.0,
            MPMediaItemPropertyMediaType: MPMediaType.music.rawValue // Changed from audioBook to music
        ]
        
        // Add genre if available
        if let genre = audioFile.genre, !genre.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyGenre] = genre
        }
        
        // Add artwork if available
        if let artworkURL = audioFile.artworkURL,
           FileManager.default.fileExists(atPath: artworkURL.path) {
            do {
                let imageData = try Data(contentsOf: artworkURL)
                if let image = UIImage(data: imageData) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    print("🖼️ Added artwork to Now Playing info")
                }
            } catch {
                print("⚠️ Could not load artwork: \(error.localizedDescription)")
            }
        }
        
        // Add additional context if playing from playlist (folder context already set above)
        if isPlayingFromPlaylist, let playlist = currentPlaylist {
            let playlistName = playlist.name ?? "Unknown Playlist"
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = (playlistName as Any)
            print("🎵 Playing from playlist: \(playlistName)")
        }
        
        // Set the Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Verify it was set
        let verifyInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        if verifyInfo != nil {
            let elapsedTime = verifyInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0.0
            let duration = verifyInfo?[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0.0
            let rate = verifyInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0
            
            print("✅ Successfully set Now Playing info with \(nowPlayingInfo.count) properties")
            print("✅ Title: \(verifyInfo?[MPMediaItemPropertyTitle] as? String ?? "nil")")
            print("✅ Artist: \(verifyInfo?[MPMediaItemPropertyArtist] as? String ?? "nil")")
            print("✅ Duration: \(duration)s, Elapsed: \(elapsedTime)s, Rate: \(rate)")
            print("✅ MPNowPlayingInfoCenter configured for Control Center")
        } else {
            print("❌ Failed to set Now Playing info!")
        }
    }
    
    // MARK: - Artwork Update Notification
    
    func artworkDidUpdate(for audioFile: AudioFile) {
        // Only update if this is the currently playing file
        guard let currentFile = currentAudioFile,
              currentFile.id == audioFile.id else {
            print("🖼️ Artwork updated for non-current file, not updating Now Playing info")
            return
        }
        
        print("🖼️ Artwork updated for current file, updating Now Playing info and UI")
        DispatchQueue.main.async { [weak self] in
            // Force UI refresh by incrementing artwork version
            self?.artworkVersion += 1
            
            // Update Control Center and lock screen
            self?.updateNowPlayingInfo()
        }
    }
    
    // MARK: - Playbook Control
    
    func loadAudioFile(_ audioFile: AudioFile, context: NSManagedObjectContext? = nil, clearGroupState: Bool = true) {
        self.viewContext = context
        
        // Save current position before switching to new file
        saveCurrentPosition()
        
        // Clear group playback state when loading a single file (unless we're part of group playback)
        if clearGroupState {
            stopGroupPlayback()
        }
        
        guard let fileURL = audioFile.fileURL else {
            let fileName = audioFile.fileName ?? "Unknown"
            print("Invalid file URL for audio file: \(fileName)")
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Audio file not found at path: \(fileURL.path)")
            return
        }
        
        // Stop current player and remove observers
        player?.pause()
        removeTimeObserver()
        removePlayerItemObservers()
        
        // Re-setup audio session before loading new file
        setupAudioSession()
        
        // Create new player item and player
        playerItem = AVPlayerItem(url: fileURL)
        player = AVPlayer(playerItem: playerItem)
        
        // Set up observers for the new player item
        setupPlayerItemObservers()
        setupTimeObserver()
        
        currentAudioFile = audioFile
        
        // Duration will be set via KVO observer
        currentTime = audioFile.currentPosition
        
        // Seek to last position if it exists
        if audioFile.currentPosition > 0 {
            let targetTime = CMTime(seconds: audioFile.currentPosition, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: targetTime)
        }
        
        // Set initial Now Playing info when file is loaded (but don't force duplicate info)
        DispatchQueue.main.async { [weak self] in
            // Only update Now Playing info once, properly
            self?.updateNowPlayingInfo()
            print("📱 Now Playing info set for loaded track")
        }
        
        let fileName = audioFile.fileName ?? "Unknown"
        print("Successfully loaded audio file: \(fileName)")
    }
    
    func play() {
        guard let player = player else { return }
        
        // Ensure audio session and remote controls are properly active
        ensureAudioSessionAndRemoteControlsActive()
        
        player.rate = Float(playbackRate)
        player.play()
        
        isPlaying = true
        
        // CRITICAL: Force Now Playing info immediately and explicitly
        DispatchQueue.main.async { [weak self] in
            self?.updateNowPlayingInfo()
            print("🎵 Forced Now Playing info update")
        }
        
        print("🎵 Playback started successfully")
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        saveCurrentPosition()
        updateNowPlayingInfo() // Update pause state in Control Center
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop() {
        player?.pause()
        isPlaying = false
        currentTime = 0
        let targetTime = CMTime(seconds: 0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: targetTime)
        saveCurrentPosition()
        updateNowPlayingInfo() // Update stop state in Control Center
    }
    
    func seek(to time: Double) {
        guard let player = player else { return }
        
        let clampedTime = min(max(time, 0), duration)
        let targetTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime)
        currentTime = clampedTime
        updateNowPlayingInfo() // Update seek position in Control Center
    }
    
    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        player?.rate = Float(rate)
        updateNowPlayingInfo() // Update playback rate in Control Center
    }
    
    func fastForward15() {
        guard let player = player else { return }
        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        let newTime = min(currentSeconds + 15, duration)
        seek(to: newTime)
    }
    
    func rewind15() {
        guard let player = player else { return }
        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        let newTime = max(currentSeconds - 15, 0)
        seek(to: newTime)
    }
    
    // MARK: - Time Observer Management
    
    private func setupTimeObserver() {
        removeTimeObserver()
        
        // Optimized: Use 1 second intervals instead of 0.5s (50% reduction in updates)
        let timeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: timeInterval, queue: .main) { [weak self] time in
            self?.updateCurrentTime(time)
        }
        print("⏱️ Time observer setup with 1.0s interval (foreground)")
    }
    
    private func setupBackgroundTimeObserver() {
        removeTimeObserver()
        
        // Background: Much slower updates (5 seconds) to save battery
        let timeInterval = CMTime(seconds: 5.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: timeInterval, queue: .main) { [weak self] time in
            self?.updateCurrentTime(time)
        }
        print("⏱️ Background time observer setup with 5.0s interval")
    }
    
    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    
    private func updateCurrentTime(_ time: CMTime) {
        guard let player = player else { return }
        
        let newTime = CMTimeGetSeconds(time)
        
        // Optimize: Avoid expensive state checks when not playing
        guard isPlaying else { return }
        
        // Check if our internal state matches the actual player state
        let playerIsActuallyPlaying = player.rate != 0 && player.error == nil
        
        if !playerIsActuallyPlaying {
            // Our state says playing, but player is actually paused
            isPlaying = false
            saveCurrentPosition()
            return
        }
        
        // Throttle updates: Only update if significant time change (0.5s threshold)
        if abs(newTime - currentTime) < 0.5 {
            return
        }
        
        // Update current time
        currentTime = newTime
        
        // Update folder progress if playing from folder (less frequently in background)
        if !isInBackground || Int(newTime) % 5 == 0 {
            updateFolderProgress()
        }
        
        // Update Now Playing info less frequently in background
        let nowPlayingInterval: Double = isInBackground ? 10.0 : 5.0
        if abs(newTime - lastNowPlayingUpdateTime) >= nowPlayingInterval {
            updateNowPlayingInfo()
            lastNowPlayingUpdateTime = newTime
            
            // Reduce logging in background
            if !isInBackground {
                print("🔄 Now Playing update - \(Int(newTime))s")
            }
        }
    }
    
    // MARK: - Folder Progress Management
    
    private func updateFolderProgress() {
        guard isPlayingFromFolder,
              let folder = currentFolder,
              currentAudioFile != nil else {
            // Not playing from folder, reset folder progress
            if folderTotalDuration != 0 || folderCurrentTime != 0 {
                folderTotalDuration = 0
                folderCurrentTime = 0
            }
            return
        }
        
        // Cache folder total duration to avoid repeated calculations
        let newTotalDuration = folder.totalDuration
        if abs(folderTotalDuration - newTotalDuration) > 1.0 {
            folderTotalDuration = newTotalDuration
        }
        
        // Update current folder position (throttle expensive calculations)
        let _ = player?.currentTime().seconds ?? currentTime
        let newFolderCurrentTime = folder.getCurrentFolderPosition()
        
        // Only update if significant change (reduce @Published updates)
        if abs(folderCurrentTime - newFolderCurrentTime) > 0.5 {
            folderCurrentTime = newFolderCurrentTime
        }
        
        // Reduce logging frequency
        if !isInBackground && Int(newFolderCurrentTime) % 10 == 0 {
            print("📁 Folder: \(Int(folderCurrentTime))s / \(Int(folderTotalDuration))s")
        }
    }
    
    // MARK: - Player Item Observers
    
    private func setupPlayerItemObservers() {
        guard let playerItem = playerItem else { return }
        
        // Observe duration
        playerItem.addObserver(self, forKeyPath: "duration", options: [.new, .initial], context: nil)
        
        // Observe status for loading state
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        // Observe when item finishes playing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    private func removePlayerItemObservers() {
        guard let playerItem = playerItem else { return }
        
        playerItem.removeObserver(self, forKeyPath: "duration")
        playerItem.removeObserver(self, forKeyPath: "status")
        
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "duration", let playerItem = object as? AVPlayerItem {
            let duration = playerItem.duration
            if duration.isValid && !duration.isIndefinite {
                DispatchQueue.main.async { [weak self] in
                    self?.duration = CMTimeGetSeconds(duration)
                    print("⏱️ Duration loaded: \(CMTimeGetSeconds(duration)) seconds")
                }
            }
        } else if keyPath == "status", let playerItem = object as? AVPlayerItem {
            DispatchQueue.main.async { [weak self] in
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ Player item ready to play")
                case .failed:
                    print("❌ Player item failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                    self?.isPlaying = false
                case .unknown:
                    print("❓ Player item status unknown")
                @unknown default:
                    break
                }
            }
        }
    }
    
    @objc private func playerDidFinishPlaying(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.currentTime = 0
            
            // Reset position to beginning
            self?.currentAudioFile?.currentPosition = 0
            try? self?.viewContext?.save()
            
            // Auto-play next track if continuous playback is enabled
            if self?.continuousPlaybackEnabled == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    var playedNext = false
                    
                    if self?.isPlayingFromGroup == true {
                        playedNext = self?.playNextInGroup() ?? false
                        if !playedNext {
                            // No next track available, stop group playback
                            self?.stopGroupPlayback()
                        }
                    } else if self?.isPlayingFromPlaylist == true {
                        playedNext = self?.playNext() ?? false
                        if !playedNext {
                            // No next track available, stop playlist playback
                            self?.stopPlaylistPlayback()
                        }
                    } else if self?.isPlayingFromFolder == true {
                        playedNext = self?.playNextInFolder() ?? false
                        if !playedNext {
                            // No next track available, stop folder playback
                            self?.stopFolderPlayback()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Core Data Operations
    
    private func saveCurrentPosition() {
        guard let audioFile = currentAudioFile else { return }
        
        audioFile.currentPosition = currentTime
        
        // Save folder state if playing from a folder
        if isPlayingFromFolder, let folder = currentFolder {
            folder.savePlaybackState(position: currentTime)
            folder.lastPlayedAudioFile = audioFile
        }
        
        // Save grouped file playback state
        if isPlayingFromGroup {
            saveGroupedFileState()
        }
        
        try? viewContext?.save()
    }
    
    private func saveGroupedFileState() {
        guard isPlayingFromGroup,
              let audioFile = currentAudioFile else { return }
        
        // Create a key combining file IDs to uniquely identify this group
        let fileIDs = groupedFilesQueue.compactMap { $0.id?.uuidString }.joined(separator: ",")
        let groupKey = "GroupedFilesState_\(fileIDs)"
        
        var state: [String: Any] = [:]
        state["currentFileID"] = audioFile.id?.uuidString
        state["currentIndex"] = currentGroupedFileIndex
        state["currentPosition"] = currentTime
        state["timestamp"] = Date().timeIntervalSince1970
        
        UserDefaults.standard.set(state, forKey: groupKey)
        print("💾 Saved grouped file state: \(groupKey) - File \(currentGroupedFileIndex + 1), Position: \(currentTime)")
    }
    
    private func restoreGroupedFileState(_ files: [AudioFile]) -> (index: Int, position: Double)? {
        guard !files.isEmpty else { return nil }
        
        // Create the same key used when saving
        let fileIDs = files.compactMap { $0.id?.uuidString }.joined(separator: ",")
        let groupKey = "GroupedFilesState_\(fileIDs)"
        
        guard let state = UserDefaults.standard.dictionary(forKey: groupKey) else {
            return nil
        }
        
        guard let currentIndex = state["currentIndex"] as? Int,
              let currentPosition = state["currentPosition"] as? Double else {
            return nil
        }
        
        // Validate the index
        guard currentIndex >= 0 && currentIndex < files.count else {
            print("⚠️ Invalid grouped file index: \(currentIndex)")
            return nil
        }
        
        print("📁 Restored grouped file state: File \(currentIndex + 1), Position: \(currentPosition)")
        return (index: currentIndex, position: currentPosition)
    }
    
    // MARK: - Playlist Playback Methods
    
    func setPlaylistManager(_ manager: PlaylistManager) {
        self.playlistManager = manager
    }
    
    func playFromPlaylist(_ audioFile: AudioFile, playlist: Playlist, context: NSManagedObjectContext) {
        self.currentPlaylist = playlist
        self.isPlayingFromPlaylist = true
        
        // Find the index of this audio file in the playlist
        if let playlistManager = playlistManager,
           let index = playlistManager.findItemIndex(for: audioFile) {
            self.currentPlaylistItemIndex = index
        }
        
        loadAudioFile(audioFile, context: context)
        play()
    }
    
    func playNext() -> Bool {
        guard isPlayingFromPlaylist,
              let _ = currentPlaylist,
              let playlistManager = playlistManager else { return false }
        
        if let nextItem = playlistManager.getNextItem(after: currentPlaylistItemIndex),
           let nextAudioFile = nextItem.audioFile {
            
            currentPlaylistItemIndex += 1
            loadAudioFile(nextAudioFile, context: viewContext)
            play()
            return true
        }
        
        return false
    }
    
    func playPrevious() -> Bool {
        guard isPlayingFromPlaylist,
              let _ = currentPlaylist,
              let playlistManager = playlistManager else { return false }
        
        if let previousItem = playlistManager.getPreviousItem(before: currentPlaylistItemIndex),
           let previousAudioFile = previousItem.audioFile {
            
            currentPlaylistItemIndex -= 1
            loadAudioFile(previousAudioFile, context: viewContext)
            play()
            return true
        }
        
        return false
    }
    
    func stopPlaylistPlayback() {
        isPlayingFromPlaylist = false
        currentPlaylist = nil
        currentPlaylistItemIndex = 0
    }
    
    // MARK: - Folder Playback Methods
    
    func playFromFolder(_ folder: Folder, resumeFromSavedState: Bool = true, context: NSManagedObjectContext) {
        self.currentFolder = folder
        self.isPlayingFromFolder = true
        
        // Clear playlist playback state
        stopPlaylistPlayback()
        
        var audioFileToPlay: AudioFile?
        var resumePosition: Double = 0.0
        
        if resumeFromSavedState && folder.hasPlaybackState() {
            // Resume from saved state
            audioFileToPlay = folder.getResumeAudioFile()
            resumePosition = folder.getResumePosition()
        } else {
            // Start from the beginning
            audioFileToPlay = folder.audioFilesArray.first
            resumePosition = 0.0
        }
        
        guard let audioFile = audioFileToPlay else { return }
        
        loadAudioFile(audioFile, context: context)
        
        // Initialize folder progress
        updateFolderProgress()
        
        // Seek to the resume position if needed
        if resumePosition > 0 {
            seek(to: resumePosition)
        }
        
        play()
    }
    
    func playNextInFolder() -> Bool {
        guard isPlayingFromFolder,
              let folder = currentFolder,
              let currentFile = currentAudioFile else { return false }
        
        let audioFiles = folder.audioFilesArray
        guard let currentIndex = audioFiles.firstIndex(of: currentFile),
              currentIndex < audioFiles.count - 1 else { return false }
        
        let nextFile = audioFiles[currentIndex + 1]
        loadAudioFile(nextFile, context: viewContext)
        play()
        return true
    }
    
    func playPreviousInFolder() -> Bool {
        guard isPlayingFromFolder,
              let folder = currentFolder,
              let currentFile = currentAudioFile else { return false }
        
        let audioFiles = folder.audioFilesArray
        guard let currentIndex = audioFiles.firstIndex(of: currentFile),
              currentIndex > 0 else { return false }
        
        let previousFile = audioFiles[currentIndex - 1]
        loadAudioFile(previousFile, context: viewContext)
        play()
        return true
    }
    
    func stopFolderPlayback() {
        isPlayingFromFolder = false
        currentFolder = nil
    }
    
    // MARK: - Grouped Files Playback Methods
    
    func playGroupedFiles(_ files: [AudioFile], context: NSManagedObjectContext) {
        playGroupedFiles(files, startingAt: 0, context: context)
    }
    
    func playGroupedFiles(_ files: [AudioFile], startingAt index: Int, context: NSManagedObjectContext) {
        guard !files.isEmpty else { return }
        guard index >= 0 && index < files.count else { return }
        
        // Clear other playback states
        stopPlaylistPlayback()
        stopFolderPlayback()
        
        self.groupedFilesQueue = files
        self.currentGroupedFileIndex = index
        self.isPlayingFromGroup = true
        
        // Load and play the file at the specified index (don't clear group state)
        loadAudioFile(files[index], context: context, clearGroupState: false)
        
        // Seek to the saved position if it was set
        let savedPosition = files[index].currentPosition
        if savedPosition > 0 {
            seek(to: savedPosition)
            print("⏳ Seeking to saved position: \(savedPosition)")
        }
        
        play()
    }
    
    func playGroupedFilesWithResume(_ files: [AudioFile], context: NSManagedObjectContext) {
        guard !files.isEmpty else { return }
        
        // Try to restore previous state
        if let (index, position) = restoreGroupedFileState(files) {
            print("📁 Resuming grouped files from file \(index + 1) at position \(position)")
            playGroupedFiles(files, startingAt: index, context: context)
            // The position will be restored by the individual file's currentPosition in playGroupedFiles
        } else {
            // Start from the beginning
            print("😀 Starting grouped files from beginning")
            playGroupedFiles(files, startingAt: 0, context: context)
        }
    }
    
    func playNextInGroup() -> Bool {
        guard isPlayingFromGroup else { return false }
        
        let nextIndex = currentGroupedFileIndex + 1
        guard nextIndex < groupedFilesQueue.count else { return false }
        
        // Save current file's position before switching
        saveCurrentPosition()
        
        currentGroupedFileIndex = nextIndex
        loadAudioFile(groupedFilesQueue[nextIndex], context: viewContext, clearGroupState: false)
        play()
        return true
    }
    
    func playPreviousInGroup() -> Bool {
        guard isPlayingFromGroup else { return false }
        
        let previousIndex = currentGroupedFileIndex - 1
        guard previousIndex >= 0 else { return false }
        
        // Save current file's position before switching
        saveCurrentPosition()
        
        currentGroupedFileIndex = previousIndex
        loadAudioFile(groupedFilesQueue[previousIndex], context: viewContext, clearGroupState: false)
        play()
        return true
    }
    
    func stopGroupPlayback() {
        isPlayingFromGroup = false
        groupedFilesQueue = []
        currentGroupedFileIndex = 0
    }
    
    func clearCurrentFile() {
        // Stop playback
        stop()
        
        // Clear the current audio file
        currentAudioFile = nil
        
        // Reset player state
        duration = 0
        currentTime = 0
        
        // Clear the player and observers
        removeTimeObserver()
        removePlayerItemObservers()
        player = nil
        playerItem = nil
        
        // Clear Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // Stop playlist playback if active
        if isPlayingFromPlaylist {
            stopPlaylistPlayback()
        }
        
        // Stop folder playback if active
        if isPlayingFromFolder {
            stopFolderPlayback()
        }
    }
}

