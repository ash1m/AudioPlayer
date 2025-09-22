//
//  VoiceControlCommands.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/17.
//

import SwiftUI
import AVFoundation
import Combine

/// Voice Control custom commands for AudioPlayer
/// Provides natural language commands for common audio player actions
class VoiceControlCommands: ObservableObject {
    
    // MARK: - Command Categories
    
    enum CommandCategory {
        case playback
        case navigation  
        case library
        case settings
        case accessibility
    }
    
    // MARK: - Custom Command Definitions
    
    struct VoiceCommand {
        let phrase: String
        let alternatives: [String]
        let category: CommandCategory
        let action: () -> Void
        let accessibilityDescription: String
    }
    
    @Published private(set) var availableCommands: [VoiceCommand] = []
    
    // MARK: - Dependencies
    
    private let audioPlayerService: AudioPlayerService
    private let audioFileManager: AudioFileManager
    private let accessibilityManager: AccessibilityManager
    
    // MARK: - Initialization
    
    init(
        audioPlayerService: AudioPlayerService,
        audioFileManager: AudioFileManager, 
        accessibilityManager: AccessibilityManager
    ) {
        self.audioPlayerService = audioPlayerService
        self.audioFileManager = audioFileManager
        self.accessibilityManager = accessibilityManager
        setupVoiceCommands()
    }
    
    // MARK: - Voice Command Setup
    
    private func setupVoiceCommands() {
        availableCommands = [
            // MARK: - Playback Commands
            
            VoiceCommand(
                phrase: "Play audio",
                alternatives: ["Start playing", "Begin playback", "Resume music"],
                category: .playback,
                action: { [weak self] in
                    self?.audioPlayerService.play()
                },
                accessibilityDescription: "Start or resume audio playback"
            ),
            
            VoiceCommand(
                phrase: "Pause audio",
                alternatives: ["Stop playing", "Pause music", "Halt playback"],
                category: .playback,
                action: { [weak self] in
                    self?.audioPlayerService.pause()
                },
                accessibilityDescription: "Pause current audio playback"
            ),
            
            VoiceCommand(
                phrase: "Skip forward",
                alternatives: ["Jump ahead", "Fast forward", "Skip ahead fifteen seconds"],
                category: .playback,
                action: { [weak self] in
                    self?.audioPlayerService.fastForward15()
                },
                accessibilityDescription: "Skip forward 15 seconds in current track"
            ),
            
            VoiceCommand(
                phrase: "Skip backward",
                alternatives: ["Jump back", "Rewind", "Skip back fifteen seconds"],
                category: .playback,
                action: { [weak self] in
                    self?.audioPlayerService.rewind15()
                },
                accessibilityDescription: "Skip backward 15 seconds in current track"
            ),
            
            VoiceCommand(
                phrase: "Next track",
                alternatives: ["Play next", "Skip to next", "Next audio"],
                category: .playback,
                action: {
                    // Next track functionality would need to be implemented
                    // For now, this is a placeholder
                },
                accessibilityDescription: "Play the next track in the queue"
            ),
            
            VoiceCommand(
                phrase: "Previous track",
                alternatives: ["Play previous", "Go back", "Previous audio"],
                category: .playback,
                action: {
                    // Previous track functionality would need to be implemented
                    // For now, this is a placeholder
                },
                accessibilityDescription: "Play the previous track in the queue"
            ),
            
            // MARK: - Speed Control Commands
            
            VoiceCommand(
                phrase: "Normal speed",
                alternatives: ["One times speed", "Regular speed", "Default playback speed"],
                category: .playback,
                action: { [weak self] in
                    self?.audioPlayerService.setPlaybackRate(1.0)
                },
                accessibilityDescription: "Set playback speed to normal (1x)"
            ),
            
            VoiceCommand(
                phrase: "Slow down",
                alternatives: ["Decrease speed", "Play slower", "Reduce playback speed"],
                category: .playback,
                action: { [weak self] in
                    let currentSpeed = self?.audioPlayerService.playbackRate ?? 1.0
                    let newSpeed = max(0.25, currentSpeed - 0.25)
                    self?.audioPlayerService.setPlaybackRate(newSpeed)
                },
                accessibilityDescription: "Decrease playback speed by 0.25x"
            ),
            
            VoiceCommand(
                phrase: "Speed up",
                alternatives: ["Increase speed", "Play faster", "Raise playback speed"],
                category: .playback,
                action: { [weak self] in
                    let currentSpeed = self?.audioPlayerService.playbackRate ?? 1.0
                    let newSpeed = min(3.0, currentSpeed + 0.25)
                    self?.audioPlayerService.setPlaybackRate(newSpeed)
                },
                accessibilityDescription: "Increase playback speed by 0.25x"
            ),
            
            // MARK: - Navigation Commands
            
            VoiceCommand(
                phrase: "Show library",
                alternatives: ["Go to library", "Open library", "Display audio files"],
                category: .navigation,
                action: { [weak self] in
                    self?.navigateToTab(.library)
                },
                accessibilityDescription: "Navigate to the audio library view"
            ),
            
            VoiceCommand(
                phrase: "Show player",
                alternatives: ["Go to player", "Open player", "Display now playing"],
                category: .navigation,
                action: { [weak self] in
                    self?.navigateToTab(.player)
                },
                accessibilityDescription: "Navigate to the audio player view"
            ),
            
            VoiceCommand(
                phrase: "Show settings",
                alternatives: ["Go to settings", "Open settings", "Display preferences"],
                category: .navigation,
                action: { [weak self] in
                    self?.navigateToTab(.settings)
                },
                accessibilityDescription: "Navigate to the app settings view"
            ),
            
            // MARK: - Library Commands
            
            VoiceCommand(
                phrase: "Import audio files",
                alternatives: ["Add new files", "Import music", "Add audio"],
                category: .library,
                action: { [weak self] in
                    self?.triggerFileImport()
                },
                accessibilityDescription: "Open file import picker to add audio files"
            ),
            
            VoiceCommand(
                phrase: "Search library",
                alternatives: ["Find audio", "Search files", "Look for music"],
                category: .library,
                action: { [weak self] in
                    self?.focusSearchField()
                },
                accessibilityDescription: "Focus the library search field"
            ),
            
            // MARK: - Sleep Timer Commands
            
            VoiceCommand(
                phrase: "Set sleep timer",
                alternatives: ["Start sleep timer", "Enable auto stop", "Set timer"],
                category: .playback,
                action: { [weak self] in
                    self?.showSleepTimerOptions()
                },
                accessibilityDescription: "Show sleep timer configuration options"
            ),
            
            VoiceCommand(
                phrase: "Cancel sleep timer",
                alternatives: ["Stop sleep timer", "Disable timer", "Turn off timer"],
                category: .playback,
                action: { [weak self] in
                    self?.accessibilityManager.cancelSleepTimer()
                },
                accessibilityDescription: "Cancel any active sleep timer"
            ),
            
            // MARK: - Accessibility Commands
            
            VoiceCommand(
                phrase: "Describe current track",
                alternatives: ["What's playing", "Current audio info", "Track details"],
                category: .accessibility,
                action: { [weak self] in
                    self?.announceCurrentTrackInfo()
                },
                accessibilityDescription: "Announce detailed information about the current track"
            ),
            
            VoiceCommand(
                phrase: "Announce playback time",
                alternatives: ["Current position", "Time remaining", "Playback status"],
                category: .accessibility,
                action: { [weak self] in
                    self?.announcePlaybackStatus()
                },
                accessibilityDescription: "Announce current playback position and remaining time"
            ),
            
            VoiceCommand(
                phrase: "List available commands",
                alternatives: ["Voice commands help", "What can I say", "Command list"],
                category: .accessibility,
                action: { [weak self] in
                    self?.announceAvailableCommands()
                },
                accessibilityDescription: "List all available voice commands"
            )
        ]
    }
    
    // MARK: - Command Actions
    
    private func navigateToTab(_ tab: TabSelection) {
        // This would require integration with the main ContentView
        // Implementation depends on app navigation structure
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToTab"),
            object: tab
        )
    }
    
    private func triggerFileImport() {
        // Trigger file import action
        NotificationCenter.default.post(
            name: NSNotification.Name("TriggerFileImport"),
            object: nil
        )
    }
    
    private func focusSearchField() {
        // Focus the search field in library view
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )
    }
    
    private func showSleepTimerOptions() {
        // Show sleep timer configuration
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowSleepTimer"),
            object: nil
        )
    }
    
    private func announceCurrentTrackInfo() {
        guard let currentTrack = audioPlayerService.currentAudioFile else {
            accessibilityManager.announceMessage(L("announcement.no.track"))
            return
        }
        
        let title = currentTrack.title ?? L("library.unknown.title")
        let artist = currentTrack.artist ?? L("library.unknown.artist")
        let duration = formatDuration(currentTrack.duration)
        let announcement = L("announcement.track.info", title, artist, duration)
        accessibilityManager.announceMessage(announcement)
    }
    
    private func announcePlaybackStatus() {
        let currentTime = audioPlayerService.currentTime
        let totalDuration = audioPlayerService.duration
        let isPlaying = audioPlayerService.isPlaying
        
        let status = isPlaying ? L("announcement.playing") : L("announcement.paused")
        let currentFormatted = formatDuration(currentTime)
        let totalFormatted = formatDuration(totalDuration)
        let announcement = L("announcement.playback.status", status, currentFormatted, totalFormatted)
        
        accessibilityManager.announceMessage(announcement)
    }
    
    private func announceAvailableCommands() {
        let playbackCommands = availableCommands
            .filter { $0.category == .playback }
            .map { $0.phrase }
            .prefix(5)
            .joined(separator: ", ")
        
        let announcement = "Available voice commands include: \(playbackCommands). Say '\(L("voice.command.list.commands"))' for more options."
        accessibilityManager.announceMessage(announcement)
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Command Registration
    
    /// Generate voice command documentation for user reference
    func generateCommandReference() -> String {
        var reference = "# Voice Control Commands for AudioPlayer\n\n"
        reference += "You can use these voice commands when Voice Control is enabled:\n\n"
        
        let categories: [(CommandCategory, String)] = [
            (.playback, "Playback Controls"),
            (.navigation, "Navigation"),
            (.library, "Library Management"),
            (.settings, "Settings"),
            (.accessibility, "Accessibility")
        ]
        
        for (category, title) in categories {
            let categoryCommands = availableCommands.filter { $0.category == category }
            if !categoryCommands.isEmpty {
                reference += "## \(title)\n\n"
                
                for command in categoryCommands {
                    reference += "### \"\(command.phrase)\"\n"
                    reference += "\(command.accessibilityDescription)\n"
                    
                    if !command.alternatives.isEmpty {
                        reference += "**Alternatives:** \(command.alternatives.joined(separator: ", "))\n"
                    }
                    
                    reference += "\n"
                }
            }
        }
        
        reference += "## Tips for Voice Control\n\n"
        reference += "- Speak clearly and at a normal pace\n"
        reference += "- Use the exact phrases listed above for best results\n"
        reference += "- Alternative phrases are provided for natural speech patterns\n"
        reference += "- Voice Control works best in quiet environments\n"
        reference += "- You can combine commands: \"Show player\" then \"Play audio\"\n"
        
        return reference
    }
    
    /// Export commands for system integration
    func getSystemVoiceControlCommands() -> [(String, String)] {
        return availableCommands.map { command in
            (command.phrase, command.accessibilityDescription)
        }
    }
}

// MARK: - Tab Selection Enum

enum TabSelection {
    case library
    case player
    case settings
}

// MARK: - SwiftUI Integration

struct VoiceControlCommandsView: View {
    let voiceControlCommands: VoiceControlCommands
    @State private var selectedCategory: VoiceControlCommands.CommandCategory = .playback
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Command Category", selection: $selectedCategory) {
                    Text("Playback").tag(VoiceControlCommands.CommandCategory.playback)
                    Text("Navigation").tag(VoiceControlCommands.CommandCategory.navigation)
                    Text("Library").tag(VoiceControlCommands.CommandCategory.library)
                    Text("Accessibility").tag(VoiceControlCommands.CommandCategory.accessibility)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                List {
                    let filteredCommands = voiceControlCommands.availableCommands.filter { 
                        $0.category == selectedCategory 
                    }
                    
                    ForEach(filteredCommands, id: \.phrase) { command in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\"\(command.phrase)\"")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(command.accessibilityDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            if !command.alternatives.isEmpty {
                                Text("Alternatives: \(command.alternatives.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Voice Commands")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview {
    VoiceControlCommandsView(
        voiceControlCommands: VoiceControlCommands(
            audioPlayerService: AudioPlayerService(),
            audioFileManager: AudioFileManager(),
            accessibilityManager: AccessibilityManager()
        )
    )
}
#endif