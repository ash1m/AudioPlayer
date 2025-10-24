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
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    @State private var selectedDuration: TimeInterval = 900 // 15 minutes default
    
    // Generate 5-minute intervals from 5 to 60 minutes
    private var presetDurations: [(String, TimeInterval)] {
        var durations: [(String, TimeInterval)] = []
        
        // Add 5-minute intervals from 5 to 60 minutes
        for minutes in stride(from: 5, through: 60, by: 5) {
            if minutes == 60 {
                durations.append((localizationManager.sleepTimerHour, TimeInterval(minutes * 60)))
            } else {
                durations.append((localizationManager.sleepTimerMinutesFormat(minutes), TimeInterval(minutes * 60)))
            }
        }
        
        return durations
    }
    
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
                    
                    Text(localizationManager.sleepTimerTitle)
                        .dynamicTypeSupport(.title, maxSize: .accessibility3)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                        .visualAccessibility()
                    
                    Text(localizationManager.sleepTimerDescription)
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
            .navigationTitle(localizationManager.sleepTimerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(accessibilityManager.sleepTimerActive)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.sleepTimerDone) {
                        dismiss()
                        if accessibilityManager.sleepTimerActive {
                            accessibilityManager.announceMessage(localizationManager.sleepTimerRunning)
                        }
                    }
                    .accessibilityLabel(localizationManager.sleepTimerCloseLabel)
                    .accessibilityHint(localizationManager.sleepTimerCloseHint)
                    .accessibleTouchTarget()
                    .visualAccessibility()
                }
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
            Text(localizationManager.sleepTimerTimerActive)
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
                
                Text(localizationManager.sleepTimerRemaining)
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
            Text(localizationManager.sleepTimerChooseDuration)
                .dynamicTypeSupport(.title2, maxSize: .accessibility2)
                .fontWeight(.medium)
                .accessibilityAddTraits(.isHeader)
                .visualAccessibility()
            
            ScrollView {
                LazyVStack(spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                    ForEach(Array(presetDurations.enumerated()), id: \.offset) { index, preset in
                        durationButton(title: preset.0, duration: preset.1)
                    }
                }
                .padding(.horizontal, AccessibleSpacing.standard(for: dynamicTypeSize))
            }
            .frame(maxHeight: 300) // Limit height to make it scrollable
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
            if accessibilityManager.sleepTimerActive {
                Button(action: cancelTimer) {
                    Text(localizationManager.sleepTimerCancel)
                        .dynamicTypeSupport(.headline, maxSize: .accessibility1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .accessiblePadding(.vertical, dynamicTypeSize: dynamicTypeSize)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .accessibilityLabel(localizationManager.sleepTimerCancelLabel)
                .accessibilityHint(localizationManager.sleepTimerCancelHint)
                .accessibleTouchTarget()
                .visualAccessibility(foreground: .white, background: .red)
                
            } else {
                Button(action: startTimer) {
                    Text(localizationManager.sleepTimerStart)
                        .dynamicTypeSupport(.headline, maxSize: .accessibility1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .accessiblePadding(.vertical, dynamicTypeSize: dynamicTypeSize)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .accessibilityLabel(localizationManager.sleepTimerStartLabel)
                .accessibilityHint(localizationManager.sleepTimerStartHint(TimeInterval(selectedDuration).accessibleDuration))
                .accessibilityValue(localizationManager.sleepTimerStartValue(TimeInterval(selectedDuration).accessibleDuration))
                .accessibleTouchTarget()
                .disabled(selectedDuration <= 0)
                .highContrastSupport(normal: .accentColor, highContrast: .primary)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func durationButton(title: String, duration: TimeInterval) -> some View {
        Button(action: {
            selectedDuration = duration
            accessibilityManager.announceMessage(localizationManager.sleepTimerSelected(title))
        }) {
            HStack {
                Text(title)
                    .dynamicTypeSupport(.body, maxSize: .accessibility1, lineLimit: 1)
                    .foregroundColor(isSelected(duration) ? .white : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected(duration) {
                    Image(systemName: "checkmark")
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
            .accessiblePadding(.all, dynamicTypeSize: dynamicTypeSize)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected(duration) ? Color.accentColor : Color(UIColor.systemGray5).opacity(accessibilityManager.isReduceTransparencyEnabled ? 1.0 : 0.8))
            )
        }
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to select \(title)")
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
    
    // MARK: - Computed Properties
    
    private var timeRemainingText: String {
        let remaining = Int(accessibilityManager.sleepTimerRemaining)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var timeRemainingAccessibilityLabel: String {
        let remaining = accessibilityManager.sleepTimerRemaining
        return localizationManager.sleepTimerTimeRemaining(TimeInterval(remaining).accessibleDuration)
    }
    
    private var progressValue: Double {
        guard accessibilityManager.sleepTimerDuration > 0 else { return 0 }
        return 1.0 - (accessibilityManager.sleepTimerRemaining / accessibilityManager.sleepTimerDuration)
    }
    
    private func isSelected(_ duration: TimeInterval) -> Bool {
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
        .environmentObject(LocalizationManager.shared)
}
