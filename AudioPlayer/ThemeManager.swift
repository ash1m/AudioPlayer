//
//  ThemeManager.swift
//  FireVox
//
//  Created by Warp AI on 2025/12/02.
//

import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = true
    @Published var themePreference: ThemePreference = .system
    
    enum ThemePreference: String, CaseIterable {
        case system = "system"
        case dark = "dark"
        case light = "light"
        
        var displayName: String {
            switch self {
            case .system:
                return "System"
            case .dark:
                return "Dark"
            case .light:
                return "Light"
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaultsKey = "themePreference"
    
    init() {
        loadThemePreference()
        setupSystemAppearanceMonitoring()
        updateThemeMode()
    }
    
    private func loadThemePreference() {
        if let savedPreference = UserDefaults.standard.string(forKey: userDefaultsKey),
           let preference = ThemePreference(rawValue: savedPreference) {
            themePreference = preference
        }
    }
    
    private func setupSystemAppearanceMonitoring() {
        NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification))
            .sink { [weak self] _ in
                self?.updateThemeMode()
            }
            .store(in: &cancellables)
    }
    
    func setThemePreference(_ preference: ThemePreference) {
        print("🎨 [ThemeManager] Setting theme preference to: \(preference.rawValue)")
        themePreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: userDefaultsKey)
        updateThemeMode()
        print("🎨 [ThemeManager] isDarkMode now: \(isDarkMode)")
    }
    
    private func updateThemeMode() {
        print("🎨 [ThemeManager] updateThemeMode called, preference: \(themePreference.rawValue)")
        switch themePreference {
        case .system:
            // Get the system appearance
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let isDarkSystemAppearance = windowScene.windows.first?.traitCollection.userInterfaceStyle == .dark
                isDarkMode = isDarkSystemAppearance
                print("🎨 [ThemeManager] System mode - isDarkSystemAppearance: \(isDarkSystemAppearance)")
            } else {
                isDarkMode = true // Default to dark
                print("🎨 [ThemeManager] System mode - no window scene, defaulting to dark")
            }
        case .dark:
            isDarkMode = true
            print("🎨 [ThemeManager] Dark mode selected")
        case .light:
            isDarkMode = false
            print("🎨 [ThemeManager] Light mode selected")
        }
        print("🎨 [ThemeManager] isDarkMode is now: \(isDarkMode)")
    }
}
