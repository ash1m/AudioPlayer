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
        themePreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: userDefaultsKey)
        updateThemeMode()
    }
    
    private func updateThemeMode() {
        switch themePreference {
        case .system:
            // Get the system appearance
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let isDarkSystemAppearance = windowScene.windows.first?.traitCollection.userInterfaceStyle == .dark
                isDarkMode = isDarkSystemAppearance
            } else {
                isDarkMode = true // Default to dark
            }
        case .dark:
            isDarkMode = true
        case .light:
            isDarkMode = false
        }
    }
}
