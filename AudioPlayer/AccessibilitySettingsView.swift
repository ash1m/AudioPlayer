//
//  AccessibilitySettingsView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/17.
//

import SwiftUI

struct AccessibilitySettingsView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.dismiss) var dismiss
    
    @State private var showSimplifiedInterface = false
    @State private var enableHapticFeedback = true
    @State private var announceTimeRemaining = true
    @State private var detailedProgressAnnouncements = true
    @State private var enableVoiceCommands = true
    @State private var isShowingUndoAlert = false
    @State private var undoMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                
                // Audio Player Specific Settings
                Section {
                    audioPlayerAccessibilitySettings
                } header: {
                    Text("Audio Player")
                        .dynamicTypeSupport(.headline, maxSize: .accessibility2)
                        .accessibilityAddTraits(.isHeader)
                } footer: {
                    Text("Customize how the audio player communicates with assistive technologies.")
                        .dynamicTypeSupport(.footnote, maxSize: .accessibility1, lineLimit: 3)
                        .visualAccessibility(foreground: .secondary)
                }
                
                // Cognitive Accessibility Section
                Section {
                    cognitiveAccessibilitySettings
                } header: {
                    Text("Cognitive Support")
                        .dynamicTypeSupport(.headline, maxSize: .accessibility2)
                        .accessibilityAddTraits(.isHeader)
                } footer: {
                    Text("Features designed to support users with cognitive differences and reduce cognitive load.")
                        .dynamicTypeSupport(.footnote, maxSize: .accessibility1, lineLimit: 4)
                        .visualAccessibility(foreground: .secondary)
                }
                
                // Motor Accessibility Section
                Section {
                    motorAccessibilitySettings
                } header: {
                    Text("Motor Accessibility")
                        .dynamicTypeSupport(.headline, maxSize: .accessibility2)
                        .accessibilityAddTraits(.isHeader)
                } footer: {
                    Text("Settings to support users with limited motor control or who use assistive devices.")
                        .dynamicTypeSupport(.footnote, maxSize: .accessibility1, lineLimit: 4)
                        .visualAccessibility(foreground: .secondary)
                }
                
                // Reset Section
                Section {
                    Button("Reset All Accessibility Settings") {
                        resetAccessibilitySettings()
                    }
                    .foregroundColor(.red)
                    .accessibilityLabel("Reset all accessibility settings")
                    .accessibilityHint("Double tap to reset all accessibility settings to default values")
                    .accessibilityAddTraits(.isButton)
                    .accessibleTouchTarget()
                } header: {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .dynamicTypeSupport(.headline, maxSize: .accessibility2)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .navigationTitle("Accessibility")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadUserSettings()
                accessibilityManager.announceScreenChange()
            }
            .alert("Settings Reset", isPresented: $isShowingUndoAlert) {
                Button("Undo") {
                    // Could implement undo functionality here
                    accessibilityManager.announceMessage("Settings restored")
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(undoMessage)
            }
        }
        .visualAccessibility(reducedMotion: true)
    }
    
    
    // MARK: - Audio Player Settings
    
    private var audioPlayerAccessibilitySettings: some View {
        VStack(spacing: 0) {
            Toggle("Detailed Progress Announcements", isOn: $detailedProgressAnnouncements)
                .accessibilityLabel("Detailed progress announcements")
                .accessibilityHint("When enabled, VoiceOver will announce detailed playback progress including time remaining")
                .accessibleTouchTarget()
                .visualAccessibility()
                .onChange(of: detailedProgressAnnouncements) { _, newValue in
                    accessibilityManager.announceMessage(newValue ? "Detailed announcements enabled" : "Detailed announcements disabled")
                }
            
            Toggle("Announce Time Remaining", isOn: $announceTimeRemaining)
                .accessibilityLabel("Announce time remaining")
                .accessibilityHint("When enabled, VoiceOver will regularly announce time remaining in the current audio")
                .accessibleTouchTarget()
                .visualAccessibility()
                .onChange(of: announceTimeRemaining) { _, newValue in
                    accessibilityManager.announceMessage(newValue ? "Time remaining announcements enabled" : "Time remaining announcements disabled")
                }
                
            if enableVoiceCommands {
                NavigationLink("Voice Commands") {
                    VoiceCommandsView()
                }
                .accessibilityLabel("Voice commands settings")
                .accessibilityHint("Configure custom voice commands for controlling playback")
                .accessibilityAddTraits(.isButton)
                .accessibleTouchTarget()
            }
        }
    }
    
    // MARK: - Cognitive Accessibility Settings
    
    private var cognitiveAccessibilitySettings: some View {
        VStack(spacing: 0) {
            Toggle("Simplified Interface", isOn: $showSimplifiedInterface)
                .accessibilityLabel("Simplified interface")
                .accessibilityHint("When enabled, shows a cleaner interface with fewer options and larger controls")
                .accessibleTouchTarget()
                .visualAccessibility()
                .onChange(of: showSimplifiedInterface) { _, newValue in
                    accessibilityManager.announceMessage(newValue ? "Simplified interface enabled" : "Standard interface enabled")
                }
            
            HStack {
                Text("Confirmation for Actions")
                    .dynamicTypeSupport(.body, maxSize: .accessibility2)
                    .visualAccessibility()
                Spacer()
                Picker("Confirmation Level", selection: .constant("Important")) {
                    Text("Never").tag("Never")
                    Text("Important Only").tag("Important")
                    Text("All Actions").tag("All")
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Confirmation level for actions")
                .accessibilityHint("Choose when to show confirmation dialogs")
            }
            .accessibleTouchTarget()
            
            Button("Test Undo Functionality") {
                testUndoFeature()
            }
            .accessibilityLabel("Test undo functionality")
            .accessibilityHint("Double tap to test the undo feature")
            .accessibilityAddTraits(.isButton)
            .accessibleTouchTarget()
            .visualAccessibility()
        }
    }
    
    // MARK: - Motor Accessibility Settings
    
    private var motorAccessibilitySettings: some View {
        VStack(spacing: 0) {
            Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                .accessibilityLabel("Haptic feedback")
                .accessibilityHint("When enabled, provides tactile feedback for button presses and interactions")
                .accessibleTouchTarget()
                .visualAccessibility()
                .onChange(of: enableHapticFeedback) { _, newValue in
                    if newValue {
                        // Provide sample haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                    accessibilityManager.announceMessage(newValue ? "Haptic feedback enabled" : "Haptic feedback disabled")
                }
            
            NavigationLink("Touch Target Size") {
                TouchTargetSettingsView()
            }
            .accessibilityLabel("Touch target size settings")
            .accessibilityHint("Adjust the size of buttons and touch targets")
            .accessibilityAddTraits(.isButton)
            .accessibleTouchTarget()
            
            NavigationLink("Switch Control Setup") {
                SwitchControlView()
            }
            .accessibilityLabel("Switch control settings")
            .accessibilityHint("Configure settings for external switch control devices")
            .accessibilityAddTraits(.isButton)
            .accessibleTouchTarget()
        }
    }
    
    // MARK: - Helper Views
    
    private func statusRow(title: String, isActive: Bool, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isActive ? .green : .gray)
                .font(.title3)
                .frame(width: 30)
                .accessibilityHidden(true)
            
            Text(title)
                .dynamicTypeSupport(.body, maxSize: .accessibility2)
                .visualAccessibility()
            
            Spacer()
            
            Text(isActive ? "On" : "Off")
                .dynamicTypeSupport(.body, maxSize: .accessibility1)
                .foregroundColor(isActive ? .green : .secondary)
                .visualAccessibility(foreground: isActive ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(isActive ? "enabled" : "disabled")")
        .accessibilityValue(isActive ? "On" : "Off")
        .accessibilityHint("This setting is controlled in the system Settings app")
    }
    
    // MARK: - Helper Methods
    
    private func loadUserSettings() {
        // Load user settings from UserDefaults or other persistence
        showSimplifiedInterface = UserDefaults.standard.bool(forKey: "showSimplifiedInterface")
        enableHapticFeedback = UserDefaults.standard.bool(forKey: "enableHapticFeedback")
        announceTimeRemaining = UserDefaults.standard.bool(forKey: "announceTimeRemaining")
        detailedProgressAnnouncements = UserDefaults.standard.bool(forKey: "detailedProgressAnnouncements")
        enableVoiceCommands = UserDefaults.standard.bool(forKey: "enableVoiceCommands")
    }
    
    private func saveUserSettings() {
        UserDefaults.standard.set(showSimplifiedInterface, forKey: "showSimplifiedInterface")
        UserDefaults.standard.set(enableHapticFeedback, forKey: "enableHapticFeedback")
        UserDefaults.standard.set(announceTimeRemaining, forKey: "announceTimeRemaining")
        UserDefaults.standard.set(detailedProgressAnnouncements, forKey: "detailedProgressAnnouncements")
        UserDefaults.standard.set(enableVoiceCommands, forKey: "enableVoiceCommands")
    }
    
    private func resetAccessibilitySettings() {
        showSimplifiedInterface = false
        enableHapticFeedback = true
        announceTimeRemaining = true
        detailedProgressAnnouncements = true
        enableVoiceCommands = true
        
        saveUserSettings()
        
        undoMessage = "All accessibility settings have been reset to their default values."
        isShowingUndoAlert = true
        
        accessibilityManager.announceMessage("Accessibility settings reset to defaults")
    }
    
    private func testUndoFeature() {
        // Example of providing undo functionality
        undoMessage = "This is a test of the undo functionality. In a real scenario, this would allow you to undo recent changes."
        isShowingUndoAlert = true
        accessibilityManager.announceMessage("Undo test triggered")
    }
}

// MARK: - Placeholder Views for Navigation

struct VoiceCommandsView: View {
    var body: some View {
        List {
            Text("Voice command settings would be implemented here")
                .dynamicTypeSupport(.body, maxSize: .accessibility2)
        }
        .navigationTitle("Voice Commands")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct TouchTargetSettingsView: View {
    @State private var touchTargetSize: Double = 44.0
    
    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 16) {
                Text("Minimum Touch Target Size")
                    .dynamicTypeSupport(.headline, maxSize: .accessibility2)
                
                HStack {
                    Text("\(Int(touchTargetSize)) points")
                        .dynamicTypeSupport(.body, maxSize: .accessibility1)
                    Spacer()
                }
                
                Slider(value: $touchTargetSize, in: 44...88, step: 4)
                    .accessibilityLabel("Touch target size")
                    .accessibilityValue("\(Int(touchTargetSize)) points")
                    .accessibilityHint("Drag to adjust minimum touch target size")
            }
        }
        .navigationTitle("Touch Targets")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SwitchControlView: View {
    var body: some View {
        List {
            Text("Switch control settings would be implemented here")
                .dynamicTypeSupport(.body, maxSize: .accessibility2)
            Text("This would include options for configuring external switches and scanning behavior.")
                .dynamicTypeSupport(.body, maxSize: .accessibility2)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Switch Control")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    AccessibilitySettingsView()
        .environmentObject(AccessibilityManager())
        .environmentObject(SettingsManager())
}
