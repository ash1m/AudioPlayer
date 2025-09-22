//
//  AccessibilityManager.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/17.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

class AccessibilityManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    @Published var isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    @Published var isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
    @Published var isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    @Published var prefersCrossFadeTransitions = UIAccessibility.prefersCrossFadeTransitions
    @Published var isHighContrastEnabled = false
    @Published var currentContentSizeCategory: ContentSizeCategory = .medium
    @Published var isLargeTextEnabled = false
    
    // Sleep timer properties
    @Published var sleepTimerDuration: TimeInterval = 0
    @Published var sleepTimerActive = false
    @Published var sleepTimerRemaining: TimeInterval = 0
    
    private var sleepTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAccessibilityNotifications()
        updateAccessibilitySettings()
    }
    
    deinit {
        sleepTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Accessibility Settings Management
    
    private func setupAccessibilityNotifications() {
        // VoiceOver status changes
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)
        
        // Reduce motion changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        
        // Reduce transparency changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
            }
            .store(in: &cancellables)
        
        // Darker colors changes
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)
        
        // Content size category changes
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .sink { [weak self] _ in
                self?.updateContentSizeCategory()
            }
            .store(in: &cancellables)
    }
    
    private func updateAccessibilitySettings() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        prefersCrossFadeTransitions = UIAccessibility.prefersCrossFadeTransitions
        updateContentSizeCategory()
        updateHighContrastSetting()
    }
    
    private func updateContentSizeCategory() {
        let category = UIApplication.shared.preferredContentSizeCategory
        currentContentSizeCategory = ContentSizeCategory(category)
        isLargeTextEnabled = category.isAccessibilityCategory
    }
    
    private func updateHighContrastSetting() {
        // Check for high contrast by detecting if darker colors are enabled
        // or if we're in a high contrast mode
        isHighContrastEnabled = isDarkerSystemColorsEnabled
    }
    
    // MARK: - VoiceOver Announcements
    
    func announceMessage(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        guard isVoiceOverRunning else { return }
        
        DispatchQueue.main.async {
            UIAccessibility.post(notification: priority, argument: message)
        }
    }
    
    func announceScreenChange() {
        guard isVoiceOverRunning else { return }
        
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
    
    func announceLayoutChange(focusElement: Any? = nil) {
        guard isVoiceOverRunning else { return }
        
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .layoutChanged, argument: focusElement)
        }
    }
    
    // MARK: - Dynamic Playback Announcements
    
    func announcePlaybackChange(isPlaying: Bool, title: String?) {
        let status = isPlaying ? L("announcement.playing") : L("announcement.paused")
        let message = title != nil ? "\(status): \(title!)" : status
        announceMessage(message)
    }
    
    func announcePlaybackSpeed(_ speed: Double) {
        let speedText = speed == 1.0 ? L("voice.command.normal.speed") : L("accessibility.speed.value", speed)
        announceMessage(L("announcement.speed.changed", speedText))
    }
    
    func announceTimeChange(current: TimeInterval, total: TimeInterval) {
        let currentFormatted = TimeInterval(current).accessibleDuration
        let totalFormatted = TimeInterval(total).accessibleDuration
        let remaining = total - current
        let remainingFormatted = TimeInterval(remaining).accessibleDuration
        
        announceMessage("\(currentFormatted) of \(totalFormatted), \(remainingFormatted) remaining")
    }
    
    func announceSkip(direction: String, seconds: Int) {
        let announcement = direction == "forward" ? 
            L("announcement.skip.forward", seconds) :
            L("announcement.skip.backward", seconds)
        announceMessage(announcement)
    }
    
    // MARK: - Enhanced Accessibility Announcements
    
    func announceTrackChange(audioFile: AudioFile?) {
        guard isVoiceOverRunning else { return }
        
        if let audioFile = audioFile {
            let title = audioFile.title ?? "Unknown title"
            let artist = audioFile.artist ?? "Unknown artist"
            let duration = TimeInterval(audioFile.duration).accessibleDuration
            
            let announcement = "Now loaded: \(title) by \(artist). Duration: \(duration)"
            announceMessage(announcement, priority: .pageScrolled)
        } else {
            announceMessage("No track selected")
        }
    }
    
    func announceChapterChange(chapterTitle: String, chapterNumber: Int, totalChapters: Int) {
        guard isVoiceOverRunning else { return }
        
        let announcement = "Chapter \(chapterNumber) of \(totalChapters): \(chapterTitle)"
        announceMessage(announcement, priority: .pageScrolled)
    }
    
    func announceBookmarkCreated(at time: TimeInterval) {
        guard isVoiceOverRunning else { return }
        
        let timeString = time.accessibleDuration
        let announcement = "Bookmark created at \(timeString)"
        announceMessage(announcement)
    }
    
    func announceBookmarkNavigation(bookmark: String, time: TimeInterval) {
        guard isVoiceOverRunning else { return }
        
        let timeString = time.accessibleDuration
        let announcement = "Jumped to bookmark: \(bookmark) at \(timeString)"
        announceMessage(announcement, priority: .pageScrolled)
    }
    
    func announcePlaylistChange(action: String, trackTitle: String) {
        guard isVoiceOverRunning else { return }
        
        let announcement = "\(trackTitle) \(action) playlist"
        announceMessage(announcement)
    }
    
    // MARK: - Folder Navigation Announcements
    
    func announceFolderNavigation(folderName: String, fileCount: Int, subfolderCount: Int) {
        guard isVoiceOverRunning else { return }
        
        var announcement = "Opened folder: \(folderName)"
        
        if subfolderCount > 0 && fileCount > 0 {
            announcement += ". Contains \(subfolderCount) folder\(subfolderCount == 1 ? "" : "s") and \(fileCount) file\(fileCount == 1 ? "" : "s")"
        } else if subfolderCount > 0 {
            announcement += ". Contains \(subfolderCount) folder\(subfolderCount == 1 ? "" : "s")"
        } else if fileCount > 0 {
            announcement += ". Contains \(fileCount) file\(fileCount == 1 ? "" : "s")"
        } else {
            announcement += ". Folder is empty"
        }
        
        announceMessage(announcement, priority: .pageScrolled)
    }
    
    func announceReturnToParent(parentName: String?) {
        guard isVoiceOverRunning else { return }
        
        let announcement: String
        if let parentName = parentName {
            announcement = "Returned to folder: \(parentName)"
        } else {
            announcement = "Returned to main library"
        }
        
        announceMessage(announcement, priority: .pageScrolled)
    }
    
    func announceReturnToLibrary() {
        guard isVoiceOverRunning else { return }
        
        announceMessage("Returned to main library", priority: .pageScrolled)
    }
    
    func announceLibraryUpdate(importedCount: Int, totalLibraryCount: Int) {
        guard isVoiceOverRunning else { return }
        
        let announcement = importedCount == 1 ? 
            "Imported 1 file. Library now has \(totalLibraryCount) files." :
            "Imported \(importedCount) files. Library now has \(totalLibraryCount) files."
        announceMessage(announcement)
    }
    
    // MARK: - Sleep Timer
    
    func startSleepTimer(duration: TimeInterval) {
        sleepTimerDuration = duration
        sleepTimerRemaining = duration
        sleepTimerActive = true
        
        announceMessage(L("announcement.timer.set", TimeInterval(duration).accessibleDuration))
        
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSleepTimer()
        }
    }
    
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerActive = false
        sleepTimerRemaining = 0
        
        announceMessage(L("announcement.timer.cancelled"))
    }
    
    private func updateSleepTimer() {
        guard sleepTimerActive else { return }
        
        sleepTimerRemaining -= 1
        
        if sleepTimerRemaining <= 0 {
            sleepTimerActive = false
            sleepTimer?.invalidate()
            sleepTimer = nil
            
            // Post notification to pause playback
            NotificationCenter.default.post(name: .sleepTimerExpired, object: nil)
            announceMessage(L("announcement.timer.expired"))
        } else {
            // Announce remaining time at key intervals
            let remaining = Int(sleepTimerRemaining)
            if remaining == 300 {
                announceMessage(L("announcement.timer.warning.5min"))
            } else if remaining == 60 {
                announceMessage(L("announcement.timer.warning.1min"))
            } else if remaining == 30 || remaining == 10 {
                let timeString = TimeInterval(sleepTimerRemaining).accessibleDuration
                announceMessage(L("announcement.timer.remaining", timeString))
            }
        }
    }
    
    // MARK: - Touch Target Validation
    
    func isValidTouchTarget(size: CGSize) -> Bool {
        return size.width >= 44 && size.height >= 44
    }
    
    func minimumTouchTargetSize() -> CGSize {
        return CGSize(width: 44, height: 44)
    }
    
    // MARK: - Color Accessibility
    
    func accessibleColor(foreground: Color, background: Color) -> Color {
        if isDarkerSystemColorsEnabled {
            return .primary
        }
        return foreground
    }
    
    func highContrastColor(base: Color, highContrast: Color) -> Color {
        return isHighContrastEnabled ? highContrast : base
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sleepTimerExpired = Notification.Name("sleepTimerExpired")
}

// MARK: - ContentSizeCategory Extension

extension ContentSizeCategory {
    init(_ uiContentSizeCategory: UIContentSizeCategory) {
        switch uiContentSizeCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: self = .medium
        }
    }
}

// MARK: - TimeInterval Accessibility Extension

extension TimeInterval {
    var accessibleDuration: String {
        guard !isNaN, !isInfinite else { return "0 seconds" }
        
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        var components: [String] = []
        
        if hours > 0 {
            components.append(hours == 1 ? "1 hour" : "\(hours) hours")
        }
        
        if minutes > 0 {
            components.append(minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }
        
        if seconds > 0 || components.isEmpty {
            components.append(seconds == 1 ? "1 second" : "\(seconds) seconds")
        }
        
        return components.joined(separator: ", ")
    }
}