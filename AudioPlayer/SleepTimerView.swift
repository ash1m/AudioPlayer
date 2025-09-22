//
//  SleepTimerView.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/17.
//

import SwiftUI

struct SleepTimerView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    @State private var selectedDuration: TimeInterval = 900 // 15 minutes default
    @State private var customMinutes: Int = 15
    @State private var isShowingCustomPicker = false
    
    private let presetDurations: [(String, TimeInterval)] = [
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("45 minutes", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200),
        ("Custom", -1)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
                // Header
                VStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: dynamicTypeSize.isLargeSize ? 48 : 60))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                        .highContrastSupport(normal: .accentColor, highContrast: .primary)
                    
                    Text("Sleep Timer")
                        .dynamicTypeSupport(.title, maxSize: .accessibility3)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                        .visualAccessibility()
                    
                    Text("Set a timer to automatically pause playback")
                        .dynamicTypeSupport(.body, maxSize: .accessibility2, lineLimit: 3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .visualAccessibility(foreground: .secondary)
                }
                .accessiblePadding(.horizontal, dynamicTypeSize: dynamicTypeSize)
                
                Spacer()
                
                // Current Timer Status
                if accessibilityManager.sleepTimerActive {
                    currentTimerStatusView
                        .transition(.opacity.combined(with: .scale))
                } else {
                    timerSelectionView
                        .transition(.opacity.combined(with: .scale))
                }
                
                Spacer()
                
                // Action Buttons
                actionButtonsView
            }
            .accessiblePadding(dynamicTypeSize: dynamicTypeSize)
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(accessibilityManager.sleepTimerActive)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        if accessibilityManager.sleepTimerActive {
                            accessibilityManager.announceMessage("Sleep timer is running")
                        }
                    }
                    .accessibilityLabel("Close sleep timer")
                    .accessibilityHint("Return to player")
                    .accessibleTouchTarget()
                    .visualAccessibility()
                }
            }
            .sheet(isPresented: $isShowingCustomPicker) {
                customTimerPickerView
            }
        }
        .visualAccessibility(reducedMotion: true)
        .onAppear {
            accessibilityManager.announceScreenChange()
        }
    }
    
    // MARK: - Current Timer Status View
    
    private var currentTimerStatusView: some View {
        VStack(spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
            Text("Timer Active")
                .dynamicTypeSupport(.title2, maxSize: .accessibility2)
                .fontWeight(.medium)
                .accessibilityAddTraits(.isHeader)
                .visualAccessibility()
            
            // Countdown Display
            VStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
                Text(timeRemainingText)
                    .dynamicTypeSupport(.largeTitle, maxSize: .accessibility1, allowsTightening: false)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
                    .accessibilityLabel(timeRemainingAccessibilityLabel)
                    .accessibilityValue(timeRemainingText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .visualAccessibility()
                
                Text("remaining")
                    .dynamicTypeSupport(.body, maxSize: .accessibility1)
                    .foregroundColor(.secondary)
                    .visualAccessibility(foreground: .secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(timeRemainingAccessibilityLabel)
            
            // Progress Ring
            if !accessibilityManager.isReduceMotionEnabled {
                timerProgressRing
                    .accessibilityHidden(true)
            }
        }
    }
    
    // MARK: - Timer Selection View
    
    private var timerSelectionView: some View {
        VStack(spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
            Text("Choose Duration")
                .dynamicTypeSupport(.title2, maxSize: .accessibility2)
                .fontWeight(.medium)
                .accessibilityAddTraits(.isHeader)
                .visualAccessibility()
            
            LazyVGrid(columns: gridColumns, spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
                ForEach(Array(presetDurations.enumerated()), id: \.offset) { index, preset in
                    durationButton(title: preset.0, duration: preset.1, isCustom: preset.1 == -1)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
            if accessibilityManager.sleepTimerActive {
                Button(action: cancelTimer) {
                    Text("Cancel Timer")
                        .dynamicTypeSupport(.headline, maxSize: .accessibility1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .accessiblePadding(.vertical, dynamicTypeSize: dynamicTypeSize)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Cancel sleep timer")
                .accessibilityHint("Stop the current sleep timer")
                .accessibleTouchTarget()
                .visualAccessibility(foreground: .white, background: .red)
                
            } else {
                Button(action: startTimer) {
                    Text("Start Timer")
                        .dynamicTypeSupport(.headline, maxSize: .accessibility1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .accessiblePadding(.vertical, dynamicTypeSize: dynamicTypeSize)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Start sleep timer")
                .accessibilityHint("Start timer for \(TimeInterval(selectedDuration).accessibleDuration)")
                .accessibilityValue("Selected duration: \(TimeInterval(selectedDuration).accessibleDuration)")
                .accessibleTouchTarget()
                .disabled(selectedDuration <= 0)
                .highContrastSupport(normal: .accentColor, highContrast: .primary)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func durationButton(title: String, duration: TimeInterval, isCustom: Bool) -> some View {
        Button(action: {
            if isCustom {
                isShowingCustomPicker = true
            } else {
                selectedDuration = duration
                accessibilityManager.announceMessage("Selected \(title)")
            }
        }) {
            Text(title)
                .dynamicTypeSupport(.body, maxSize: .accessibility1, lineLimit: 2)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected(duration) ? .white : .primary)
                .frame(maxWidth: .infinity)
                .accessiblePadding(.vertical, dynamicTypeSize: dynamicTypeSize)
                .background(
                    isSelected(duration) ? 
                        Color.accentColor : 
                        Color(UIColor.systemGray5).opacity(accessibilityManager.isReduceTransparencyEnabled ? 1.0 : 0.8)
                )
                .cornerRadius(8)
        }
        .accessibilityLabel(isCustom ? "Custom duration" : title)
        .accessibilityHint(isCustom ? "Double tap to set custom duration" : "Double tap to select \(title)")
        .accessibilityAddTraits(isSelected(duration) ? [.isButton, .isSelected] : .isButton)
        .accessibleTouchTarget()
        .highContrastSupport(
            normal: isSelected(duration) ? .accentColor : .clear,
            highContrast: isSelected(duration) ? .primary : .secondary
        )
    }
    
    private var timerProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            
            Circle()
                .trim(from: 0.0, to: progressValue)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: progressValue)
        }
        .frame(width: dynamicTypeSize.isLargeSize ? 120 : 150, height: dynamicTypeSize.isLargeSize ? 120 : 150)
        .highContrastSupport(normal: .accentColor, highContrast: .primary)
    }
    
    private var customTimerPickerView: some View {
        NavigationStack {
            VStack(spacing: AccessibleSpacing.expanded(for: dynamicTypeSize)) {
                Text("Custom Duration")
                    .dynamicTypeSupport(.title2, maxSize: .accessibility2)
                    .fontWeight(.medium)
                    .accessibilityAddTraits(.isHeader)
                
                Picker("Minutes", selection: $customMinutes) {
                    ForEach(1...180, id: \.self) { minutes in
                        Text("\(minutes) minute\(minutes == 1 ? "" : "s")")
                            .tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityLabel("Duration in minutes")
                .accessibilityValue("\(customMinutes) minutes")
                .accessibilityHint("Scroll to select custom duration")
                
                Button("Set Custom Timer") {
                    selectedDuration = TimeInterval(customMinutes * 60)
                    isShowingCustomPicker = false
                    accessibilityManager.announceMessage("Custom timer set for \(customMinutes) minute\(customMinutes == 1 ? "" : "s")")
                }
                .dynamicTypeSupport(.headline, maxSize: .accessibility1)
                .accessibleTouchTarget()
                .visualAccessibility()
            }
            .accessiblePadding(dynamicTypeSize: dynamicTypeSize)
            .navigationTitle("Custom Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isShowingCustomPicker = false
                    }
                    .accessibleTouchTarget()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var gridColumns: [GridItem] {
        let columnCount = dynamicTypeSize.isLargeSize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: AccessibleSpacing.standard(for: dynamicTypeSize)), count: columnCount)
    }
    
    private var timeRemainingText: String {
        let remaining = Int(accessibilityManager.sleepTimerRemaining)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var timeRemainingAccessibilityLabel: String {
        let remaining = accessibilityManager.sleepTimerRemaining
        return "Time remaining: \(TimeInterval(remaining).accessibleDuration)"
    }
    
    private var progressValue: Double {
        guard accessibilityManager.sleepTimerDuration > 0 else { return 0 }
        return 1.0 - (accessibilityManager.sleepTimerRemaining / accessibilityManager.sleepTimerDuration)
    }
    
    private func isSelected(_ duration: TimeInterval) -> Bool {
        if duration == -1 {
            // Custom option selected if selectedDuration is not in presets
            return !presetDurations.contains { $0.1 == selectedDuration }
        }
        return selectedDuration == duration
    }
    
    // MARK: - Actions
    
    private func startTimer() {
        accessibilityManager.startSleepTimer(duration: selectedDuration)
        dismiss()
    }
    
    private func cancelTimer() {
        accessibilityManager.cancelSleepTimer()
    }
}

#Preview {
    SleepTimerView()
        .environmentObject(AccessibilityManager())
        .environmentObject(AudioPlayerService())
}