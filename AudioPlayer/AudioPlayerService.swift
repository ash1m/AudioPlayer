//
//  AudioPlayerService.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import Foundation
import AVFoundation
import MediaPlayer
import CoreData
import Combine

class AudioPlayerService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackRate: Double = 1.0
    @Published var currentAudioFile: AudioFile?
    @Published var isPlayingFromPlaylist = false
    @Published var continuousPlaybackEnabled = true
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var updateTimer: Timer?
    private var viewContext: NSManagedObjectContext?
    
    // MARK: - Playlist Queue Properties
    private var currentPlaylist: Playlist?
    private var currentPlaylistItemIndex: Int = 0
    private weak var playlistManager: PlaylistManager?
    
    override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    deinit {
        stopUpdateTimer()
        audioPlayer?.stop()
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
    }
    
    @objc private func handleSleepTimerExpired() {
        pause()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure audio session for background playback
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
            
            // Set the audio session active
            try audioSession.setActive(true)
            
            // Configure for background audio
            setupRemoteTransportControls()
            
            print("Audio session configured successfully")
            
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Skip forward command
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.fastForward15()
            return .success
        }
        
        // Skip backward command
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.rewind15()
            return .success
        }
    }
    
    // MARK: - Playback Control
    
    func loadAudioFile(_ audioFile: AudioFile, context: NSManagedObjectContext? = nil) {
        self.viewContext = context
        
        // Save current position before switching to new file
        saveCurrentPosition()
        
        guard let fileURL = audioFile.fileURL else {
            print("Invalid file URL for audio file: \(audioFile.fileName)")
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Audio file not found at path: \(fileURL.path)")
            return
        }
        
        do {
            // Stop current player
            audioPlayer?.stop()
            
            // Re-setup audio session before loading new file
            setupAudioSession()
            
            // Create new audio player
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true // Enable rate control
            audioPlayer?.prepareToPlay()
            
            currentAudioFile = audioFile
            duration = audioPlayer?.duration ?? 0
            currentTime = audioFile.currentPosition
            
            // Seek to last position if it exists
            if audioFile.currentPosition > 0 {
                audioPlayer?.currentTime = audioFile.currentPosition
            }
            
            print("Successfully loaded audio file: \(audioFile.fileName)")
            
        } catch {
            print("Error loading audio file \(audioFile.fileName): \(error.localizedDescription)")
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        player.rate = Float(playbackRate)
        player.play()
        isPlaying = true
        startUpdateTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopUpdateTimer()
        saveCurrentPosition()
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0
        stopUpdateTimer()
        saveCurrentPosition()
    }
    
    func seek(to time: Double) {
        guard let player = audioPlayer else { return }
        
        player.currentTime = min(max(time, 0), duration)
        currentTime = player.currentTime
    }
    
    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        audioPlayer?.rate = Float(rate)
    }
    
    func fastForward15() {
        guard let player = audioPlayer else { return }
        let newTime = min(player.currentTime + 15, duration)
        seek(to: newTime)
    }
    
    func rewind15() {
        guard let player = audioPlayer else { return }
        let newTime = max(player.currentTime - 15, 0)
        seek(to: newTime)
    }
    
    // MARK: - Timer Management
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateCurrentTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
    }
    
    // MARK: - Core Data Operations
    
    private func saveCurrentPosition() {
        guard let audioFile = currentAudioFile else { return }
        
        audioFile.currentPosition = currentTime
        try? viewContext?.save()
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
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopUpdateTimer()
        
        // Reset position to beginning
        currentAudioFile?.currentPosition = 0
        try? viewContext?.save()
        
        // Auto-play next track if continuous playback is enabled and playing from playlist
        if continuousPlaybackEnabled && isPlayingFromPlaylist && flag {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if !(self?.playNext() ?? false) {
                    // No next track available, stop playlist playback
                    self?.stopPlaylistPlayback()
                }
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        isPlaying = false
        stopUpdateTimer()
    }
}