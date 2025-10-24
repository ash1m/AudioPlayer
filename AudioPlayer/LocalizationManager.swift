//
//  LocalizationManager.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/17.
//

import Foundation
import SwiftUI
import Combine

/// Manages localization and provides easy access to localized strings
class LocalizationManager: ObservableObject {
    
    // MARK: - Current Language
    @Published var currentLanguage: String = "en" {
        didSet {
            // Force UI update when language changes
            objectWillChange.send()
        }
    }
    
    // MARK: - Language Bundle
    private var languageBundle: Bundle?
    
    // MARK: - Supported Languages
    static let supportedLanguages = [
        "en": "English",
        "es": "Español"
    ]
    
    // MARK: - Shared Instance
    static let shared = LocalizationManager()
    
    private init() {
        // Initialize with saved language or system language if supported, otherwise default to English
        let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? Locale.current.language.languageCode?.identifier ?? "en"
        currentLanguage = Self.supportedLanguages.keys.contains(savedLanguage) ? savedLanguage : "en"
        updateLanguageBundle()
    }
    
    // MARK: - Language Management
    
    /// Updates the current language and saves to UserDefaults
    func setLanguage(_ languageCode: String) {
        guard Self.supportedLanguages.keys.contains(languageCode) else {
            print("Unsupported language: \(languageCode)")
            return
        }
        
        currentLanguage = languageCode
        UserDefaults.standard.set(languageCode, forKey: "selectedLanguage")
        updateLanguageBundle()
    }
    
    /// Updates the language bundle for string localization
    private func updateLanguageBundle() {
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj") else {
            print("Could not find bundle for language: \(currentLanguage)")
            languageBundle = Bundle.main
            return
        }
        languageBundle = Bundle(path: path)
    }
    
    // MARK: - String Localization
    
    /// Get localized string for key
    func localizedString(_ key: String, comment: String = "") -> String {
        guard let bundle = languageBundle else {
            return key
        }
        let localizedString = bundle.localizedString(forKey: key, value: key, table: nil)
        return localizedString != key ? localizedString : key
    }
    
    /// Get localized string with arguments
    func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: arguments)
    }
    
    // MARK: - App Navigation
    
    var tabLibrary: String { localizedString("tab.library") }
    var tabPlaylist: String { localizedString("tab.playlist") }
    var tabPlayer: String { localizedString("tab.player") }
    var tabSettings: String { localizedString("tab.settings") }
    
    // MARK: - Library View
    
    var libraryTitle: String { localizedString("library.title") }
    var librarySearchPlaceholder: String { localizedString("library.search.placeholder") }
    var libraryImportButton: String { localizedString("library.import.button") }
    var libraryEmptyTitle: String { localizedString("library.empty.title") }
    var libraryEmptyMessage: String { localizedString("library.empty.message") }
    var libraryUnknownTitle: String { localizedString("library.unknown.title") }
    var libraryUnknownArtist: String { localizedString("library.unknown.artist") }
    var libraryUnknownAlbum: String { localizedString("library.unknown.album") }
    
    // MARK: - Audio Player
    
    var playerPlay: String { localizedString("player.play") }
    var playerPause: String { localizedString("player.pause") }
    var playerSkipForward: String { localizedString("player.skip.forward") }
    var playerSkipBackward: String { localizedString("player.skip.backward") }
    var playerSpeedControl: String { localizedString("player.speed.control") }
    var playerProgress: String { localizedString("player.progress") }
    var playerVolume: String { localizedString("player.volume") }
    var playerNoTrack: String { localizedString("player.no.track") }
    
    // MARK: - Sleep Timer
    
    var sleepTimerTitle: String { localizedString("sleep.timer.title") }
    var sleepTimerDescription: String { localizedString("sleep.timer.description") }
    var sleepTimerChooseDuration: String { localizedString("sleep.timer.choose.duration") }
    var sleepTimerTimerActive: String { localizedString("sleep.timer.timer.active") }
    var sleepTimerRemaining: String { localizedString("sleep.timer.remaining") }
    var sleepTimerStart: String { localizedString("sleep.timer.start") }
    var sleepTimerCancel: String { localizedString("sleep.timer.cancel") }
    var sleepTimerDone: String { localizedString("sleep.timer.done") }
    var sleepTimerHour: String { localizedString("sleep.timer.hour") }
    var sleepTimerCloseLabel: String { localizedString("sleep.timer.close.label") }
    var sleepTimerCloseHint: String { localizedString("sleep.timer.close.hint") }
    var sleepTimerStartLabel: String { localizedString("sleep.timer.start.label") }
    var sleepTimerCancelLabel: String { localizedString("sleep.timer.cancel.label") }
    var sleepTimerCancelHint: String { localizedString("sleep.timer.cancel.hint") }
    var sleepTimerRunning: String { localizedString("sleep.timer.running") }
    
    func sleepTimerMinutesFormat(_ minutes: Int) -> String {
        localizedString("sleep.timer.minutes.format", minutes)
    }
    
    func sleepTimerStartHint(_ duration: String) -> String {
        localizedString("sleep.timer.start.hint", duration)
    }
    
    func sleepTimerStartValue(_ duration: String) -> String {
        localizedString("sleep.timer.start.value", duration)
    }
    
    func sleepTimerSelected(_ duration: String) -> String {
        localizedString("sleep.timer.selected", duration)
    }
    
    func sleepTimerTimeRemaining(_ time: String) -> String {
        localizedString("sleep.timer.time.remaining", time)
    }
    
    // MARK: - Settings
    
    var settingsTitle: String { localizedString("settings.title") }
    var settingsImport: String { localizedString("settings.import") }
    var settingsAccessibility: String { localizedString("settings.accessibility") }
    var settingsAbout: String { localizedString("settings.about") }
    var settingsVersion: String { localizedString("settings.version") }
    var settingsBuild: String { localizedString("settings.build") }
    
    // MARK: - Accessibility Settings
    
    var accessibilityTitle: String { localizedString("accessibility.title") }
    var accessibilityVoiceOver: String { localizedString("accessibility.voiceover") }
    var accessibilityVoiceControl: String { localizedString("accessibility.voice.control") }
    var accessibilityDynamicType: String { localizedString("accessibility.dynamic.type") }
    var accessibilityReduceMotion: String { localizedString("accessibility.reduce.motion") }
    var accessibilityHighContrast: String { localizedString("accessibility.high.contrast") }
    var accessibilityButtonShapes: String { localizedString("accessibility.button.shapes") }
    var accessibilityTestSuite: String { localizedString("accessibility.test.suite") }
    var accessibilityValidation: String { localizedString("accessibility.validation") }
    
    // MARK: - VoiceOver Accessibility Labels
    
    var accessibilityPlayButton: String { localizedString("accessibility.play.button") }
    var accessibilityPauseButton: String { localizedString("accessibility.pause.button") }
    var accessibilitySkipForwardButton: String { localizedString("accessibility.skip.forward.button") }
    var accessibilitySkipBackwardButton: String { localizedString("accessibility.skip.backward.button") }
    var accessibilityProgressSlider: String { localizedString("accessibility.progress.slider") }
    var accessibilitySpeedButton: String { localizedString("accessibility.speed.button") }
    var accessibilityVolumeSlider: String { localizedString("accessibility.volume.slider") }
    var accessibilityLibrarySearch: String { localizedString("accessibility.library.search") }
    var accessibilityImportButton: String { localizedString("accessibility.import.button") }
    var accessibilitySleepTimerButton: String { localizedString("accessibility.sleep.timer.button") }
    
    // MARK: - VoiceOver Accessibility Hints
    
    var accessibilityPlayHint: String { localizedString("accessibility.play.hint") }
    var accessibilityPauseHint: String { localizedString("accessibility.pause.hint") }
    var accessibilitySkipForwardHint: String { localizedString("accessibility.skip.forward.hint") }
    var accessibilitySkipBackwardHint: String { localizedString("accessibility.skip.backward.hint") }
    var accessibilityProgressHint: String { localizedString("accessibility.progress.hint") }
    var accessibilitySpeedHint: String { localizedString("accessibility.speed.hint") }
    var accessibilityVolumeHint: String { localizedString("accessibility.volume.hint") }
    var accessibilityLibrarySearchHint: String { localizedString("accessibility.library.search.hint") }
    var accessibilityImportHint: String { localizedString("accessibility.import.hint") }
    var accessibilitySleepTimerHint: String { localizedString("accessibility.sleep.timer.hint") }
    
    // MARK: - VoiceOver Accessibility Values
    
    func accessibilityProgressValue(_ current: String, _ total: String) -> String {
        localizedString("accessibility.progress.value", current, total)
    }
    
    func accessibilitySpeedValue(_ speed: Double) -> String {
        localizedString("accessibility.speed.value", speed)
    }
    
    func accessibilityVolumeValue(_ volume: Int) -> String {
        localizedString("accessibility.volume.value", volume)
    }
    
    func accessibilityTimerValue(_ remaining: String) -> String {
        localizedString("accessibility.timer.value", remaining)
    }
    
    // MARK: - Voice Control Commands
    
    var voiceCommandPlay: String { localizedString("voice.command.play") }
    var voiceCommandPause: String { localizedString("voice.command.pause") }
    var voiceCommandSkipForward: String { localizedString("voice.command.skip.forward") }
    var voiceCommandSkipBackward: String { localizedString("voice.command.skip.backward") }
    var voiceCommandNextTrack: String { localizedString("voice.command.next.track") }
    var voiceCommandPreviousTrack: String { localizedString("voice.command.previous.track") }
    var voiceCommandNormalSpeed: String { localizedString("voice.command.normal.speed") }
    var voiceCommandSlowDown: String { localizedString("voice.command.slow.down") }
    var voiceCommandSpeedUp: String { localizedString("voice.command.speed.up") }
    var voiceCommandShowLibrary: String { localizedString("voice.command.show.library") }
    var voiceCommandShowPlayer: String { localizedString("voice.command.show.player") }
    var voiceCommandShowSettings: String { localizedString("voice.command.show.settings") }
    var voiceCommandImportFiles: String { localizedString("voice.command.import.files") }
    var voiceCommandSearchLibrary: String { localizedString("voice.command.search.library") }
    var voiceCommandSetSleepTimer: String { localizedString("voice.command.set.sleep.timer") }
    var voiceCommandCancelSleepTimer: String { localizedString("voice.command.cancel.sleep.timer") }
    var voiceCommandDescribeTrack: String { localizedString("voice.command.describe.track") }
    var voiceCommandAnnounceTime: String { localizedString("voice.command.announce.time") }
    var voiceCommandListCommands: String { localizedString("voice.command.list.commands") }
    
    // MARK: - VoiceOver Announcements
    
    var announcementPlaying: String { localizedString("announcement.playing") }
    var announcementPaused: String { localizedString("announcement.paused") }
    var announcementNoTrack: String { localizedString("announcement.no.track") }
    
    func announcementTrackInfo(_ title: String, _ artist: String, _ duration: String) -> String {
        localizedString("announcement.track.info", title, artist, duration)
    }
    
    func announcementPlaybackStatus(_ status: String, _ current: String, _ total: String) -> String {
        localizedString("announcement.playback.status", status, current, total)
    }
    
    func announcementSpeedChanged(_ speed: String) -> String {
        localizedString("announcement.speed.changed", speed)
    }
    
    func announcementSkipForward(_ seconds: Int) -> String {
        localizedString("announcement.skip.forward", seconds)
    }
    
    func announcementSkipBackward(_ seconds: Int) -> String {
        localizedString("announcement.skip.backward", seconds)
    }
    
    // MARK: - Sleep Timer Announcements
    
    func announcementTimerSet(_ duration: String) -> String {
        localizedString("announcement.timer.set", duration)
    }
    
    var announcementTimerCancelled: String { localizedString("announcement.timer.cancelled") }
    var announcementTimerExpired: String { localizedString("announcement.timer.expired") }
    var announcementTimerWarning5Min: String { localizedString("announcement.timer.warning.5min") }
    var announcementTimerWarning1Min: String { localizedString("announcement.timer.warning.1min") }
    
    func announcementTimerRemaining(_ time: String) -> String {
        localizedString("announcement.timer.remaining", time)
    }
    
    // MARK: - Error Messages
    
    var errorFileNotFound: String { localizedString("error.file.not.found") }
    var errorUnsupportedFormat: String { localizedString("error.unsupported.format") }
    var errorImportFailed: String { localizedString("error.import.failed") }
    var errorPlaybackFailed: String { localizedString("error.playback.failed") }
    var errorPermissionDenied: String { localizedString("error.permission.denied") }
    
    // MARK: - File Import
    
    var importTitle: String { localizedString("import.title") }
    var importSelecting: String { localizedString("import.selecting") }
    var importProcessing: String { localizedString("import.processing") }
    var importFailed: String { localizedString("import.failed") }
    
    func importSuccess(_ count: Int) -> String {
        localizedString("import.success", count)
    }
    
    func importPartialSuccess(_ imported: Int, _ total: Int) -> String {
        localizedString("import.partial.success", imported, total)
    }
    
    // MARK: - Import Results
    
    var importResultsTitle: String { localizedString("import.results.title") }
    var importSuccessSingle: String { localizedString("import.success.single") }
    var importProgressImporting: String { localizedString("import.progress.importing") }
    var importDetailsTitle: String { localizedString("import.details.title") }
    var importButtonOK: String { localizedString("import.button.ok") }
    var importButtonViewDetails: String { localizedString("import.button.view.details") }
    var importButtonDone: String { localizedString("import.button.done") }
    
    func importSuccessMultiple(_ count: Int) -> String {
        localizedString("import.success.multiple", count)
    }
    
    func importFailureAll(_ count: Int) -> String {
        localizedString("import.failure.all", count)
    }
    
    func importPartialSuccessDetailed(_ successCount: Int, _ failureCount: Int) -> String {
        localizedString("import.partial.success", successCount, failureCount)
    }
    
    func importDetailsSuccessSection(_ count: Int) -> String {
        localizedString("import.details.success.section", count)
    }
    
    func importDetailsFailureSection(_ count: Int) -> String {
        localizedString("import.details.failure.section", count)
    }
    
    // MARK: - Common Actions
    
    var actionCancel: String { localizedString("action.cancel") }
    var actionDone: String { localizedString("action.done") }
    var actionOK: String { localizedString("action.ok") }
    var actionSave: String { localizedString("action.save") }
    var actionDelete: String { localizedString("action.delete") }
    var actionEdit: String { localizedString("action.edit") }
    var actionAdd: String { localizedString("action.add") }
    var actionRemove: String { localizedString("action.remove") }
    var actionClose: String { localizedString("action.close") }
    var actionBack: String { localizedString("action.back") }
    var actionNext: String { localizedString("action.next") }
    var actionPrevious: String { localizedString("action.previous") }
    var actionRetry: String { localizedString("action.retry") }
    
    // MARK: - Test Suite Strings
    
    var testSuiteTitle: String { localizedString("test.suite.title") }
    var testSuiteRunning: String { localizedString("test.suite.running") }
    var testSuiteVoiceOverLabels: String { localizedString("test.suite.voiceover.labels") }
    var testSuiteTouchTargets: String { localizedString("test.suite.touch.targets") }
    var testSuiteDynamicType: String { localizedString("test.suite.dynamic.type") }
    var testSuiteColorContrast: String { localizedString("test.suite.color.contrast") }
    var testSuiteMotionPreferences: String { localizedString("test.suite.motion.preferences") }
    var testSuiteFocusManagement: String { localizedString("test.suite.focus.management") }
    var testSuiteVoiceControl: String { localizedString("test.suite.voice.control") }
    var testSuiteNoIssues: String { localizedString("test.suite.no.issues") }
    var testSuiteRefresh: String { localizedString("test.suite.refresh") }
    var testSuiteGenerateReport: String { localizedString("test.suite.generate.report") }
    
    func testSuiteCriticalIssues(_ count: Int) -> String {
        localizedString("test.suite.critical.issues", count)
    }
    
    func testSuiteWarnings(_ count: Int) -> String {
        localizedString("test.suite.warnings", count)
    }
    
    func testSuiteSuggestions(_ count: Int) -> String {
        localizedString("test.suite.suggestions", count)
    }
    
    // MARK: - Validation Strings
    
    var validationTitle: String { localizedString("validation.title") }
    var validationContinuous: String { localizedString("validation.continuous") }
    var validationIssuesDetected: String { localizedString("validation.issues.detected") }
    var validationCriticalAlertTitle: String { localizedString("validation.critical.alert.title") }
    var validationOK: String { localizedString("validation.ok") }
    
    func validationCriticalAlertMessage(_ count: Int) -> String {
        localizedString("validation.critical.alert.message", count)
    }
}

// MARK: - SwiftUI Integration

extension LocalizationManager {
    /// Environment key for LocalizationManager
    struct LocalizationManagerKey: EnvironmentKey {
        static let defaultValue = LocalizationManager.shared
    }
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationManager.LocalizationManagerKey.self] }
        set { self[LocalizationManager.LocalizationManagerKey.self] = newValue }
    }
}

// MARK: - Convenience Functions

/// Quick access to localized strings
func L(_ key: String, comment: String = "") -> String {
    return LocalizationManager.shared.localizedString(key, comment: comment)
}

/// Quick access to localized strings with arguments
func L(_ key: String, _ arguments: CVarArg...) -> String {
    return LocalizationManager.shared.localizedString(key, arguments)
}

// MARK: - View Extension for Easy Access

extension View {
    func localized() -> some View {
        self.environmentObject(LocalizationManager.shared)
    }
}