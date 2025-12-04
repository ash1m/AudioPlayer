//
//  AppTheme.swift
//  FireVox
//
//  Created by Warp AI on 2025/12/02.
//

import SwiftUI

struct AppTheme {
    let isDark: Bool
    
    // MARK: - Background Colors
    var backgroundColor: Color {
        isDark ? Color.black : Color(UIColor(red: 0.85, green: 0.84, blue: 0.81, alpha: 1))
    }
    
    var secondaryBackgroundColor: Color {
        isDark ? Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)) : Color(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1))
    }
    
    var cardBackgroundColor: Color {
        isDark ? Color(UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)) : Color(UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1))
    }
    
    // MARK: - Text Colors
    var textColor: Color {
        isDark ? Color.white : Color.black
    }
    
    var secondaryTextColor: Color {
        isDark ? Color(UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)) : Color(UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1))
    }
    
    var tertiaryTextColor: Color {
        isDark ? Color(UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)) : Color(UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
    }
    
    // MARK: - Border & Divider Colors
    var borderColor: Color {
        isDark ? Color(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)) : Color(UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1))
    }
    
    var dividerColor: Color {
        isDark ? Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)) : Color(UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1))
    }
    
    // MARK: - Shadow & Overlay Colors
    var shadowColor: Color {
        isDark ? Color.black.opacity(0.5) : Color.black.opacity(0.3)
    }
    
    var overlayColor: Color {
        isDark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }
    
    var glassBackgroundColor: Color {
        isDark ? Color.black.opacity(0.6) : Color.white.opacity(0.6)
    }
    
    // MARK: - Button & Interactive Colors
    var buttonBackgroundColor: Color {
        isDark ? Color(UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)) : Color(UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1))
    }
    
    var buttonPressedColor: Color {
        isDark ? Color(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)) : Color(UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1))
    }
    
    // MARK: - Accent Colors
    var accentColor: Color {
        Color.blue // Consistent across themes
    }
    
    var destructiveColor: Color {
        Color.red // Consistent across themes
    }
    
    // MARK: - Status Colors
    var successColor: Color {
        Color.green
    }
    
    var warningColor: Color {
        Color.orange
    }
    
    var errorColor: Color {
        Color.red
    }
    
    // MARK: - Gradient Helper
    func gradientOverlay() -> LinearGradient {
        if isDark {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Environment Key for Easy Access
struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(isDark: true)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
