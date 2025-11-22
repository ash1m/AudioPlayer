//
//  SettingsManager.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/16.
//

import Foundation
import Combine

class SettingsManager: ObservableObject {
    
    enum Language: String, CaseIterable {
        case english = "en"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        case italian = "it"
        case portuguese = "pt"
        case japanese = "ja"
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Español"
            case .french: return "Français"
            case .german: return "Deutsch"
            case .italian: return "Italiano"
            case .portuguese: return "Português"
            case .japanese: return "日本語"
            }
        }
    }
    
    enum PlaybackSpeed: Double, CaseIterable {
        case quarter = 0.25
        case half = 0.5
        case threeQuarter = 0.75
        case normal = 1.0
        case oneTwentyFive = 1.25
        case oneHalf = 1.5
        case double = 2.0
        case triple = 3.0
        
        var displayName: String {
            switch self {
            case .quarter: return "0.25x"
            case .half: return "0.5x"
            case .threeQuarter: return "0.75x"
            case .normal: return "1x (Normal)"
            case .oneTwentyFive: return "1.25x"
            case .oneHalf: return "1.5x"
            case .double: return "2x"
            case .triple: return "3x"
            }
        }
    }
    
    @Published var selectedLanguage: Language {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "selectedLanguage")
            // Update LocalizationManager with the new language
            LocalizationManager.shared.setLanguage(selectedLanguage.rawValue)
        }
    }
    
    @Published var defaultPlaybackSpeed: PlaybackSpeed {
        didSet {
            UserDefaults.standard.set(defaultPlaybackSpeed.rawValue, forKey: "defaultPlaybackSpeed")
        }
    }
    
    init() {
        // Load saved language or default to English
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: savedLanguage) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .english
        }
        
        // Load saved playback speed or default to normal
        let savedSpeed = UserDefaults.standard.double(forKey: "defaultPlaybackSpeed")
        if savedSpeed > 0, let speed = PlaybackSpeed(rawValue: savedSpeed) {
            self.defaultPlaybackSpeed = speed
        } else {
            self.defaultPlaybackSpeed = .normal
        }
        
        // Initialize LocalizationManager with the selected language
        LocalizationManager.shared.setLanguage(selectedLanguage.rawValue)
    }
    
    // Helper method to get localized strings (basic implementation)
    func localizedString(_ key: String) -> String {
        // In a full implementation, this would return properly localized strings
        // For now, we'll return English strings
        switch key {
        case "library": return "Library"
        case "player": return "Player" 
        case "settings": return "Settings"
        case "import": return "Import"
        case "language": return "Language"
        case "playback_speed": return "Playback Speed"
        case "supported_formats": return "Supported Formats"
        case "choose_files_folders": return "Choose Files or Folders"
        default: return key
        }
    }
}
