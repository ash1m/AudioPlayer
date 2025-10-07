//
//  FontManager.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import SwiftUI
import UIKit

struct FontManager {
    
    // MARK: - Font Names
    static let customFontFamily = "InstrumentSerif"
    
    // MARK: - Font Weights
    enum FontWeight: String {
        case regular = "Regular"
        case italic = "Italic"
        
        var fontName: String {
            return "\(FontManager.customFontFamily)-\(self.rawValue)"
        }
        
        // Fallback for weights not available in Instrument Serif
        var systemWeight: Font.Weight {
            switch self {
            case .regular:
                return .regular
            case .italic:
                return .regular // Italic is a style, not weight
            }
        }
    }
    
    // MARK: - Font Sizes
    enum FontSize: CGFloat {
        case caption = 12
        case caption2 = 11
        case footnote = 13
        case subheadline = 15
        case callout = 16
        case body = 17
        case headline = 18
        case title3 = 20
        case title2 = 22
        case title = 28
        case largeTitle = 34
        
        // Custom sizes for your app
        case playerTitle = 24
        case playerSubtitle = 19
        case controlLabel = 14
    }
    
    // MARK: - Font Creation Methods
    static func font(_ weight: FontWeight, size: FontSize) -> Font {
        return Font.custom(weight.fontName, size: size.rawValue)
    }
    
    static func font(_ weight: FontWeight, size: CGFloat) -> Font {
        return Font.custom(weight.fontName, size: size)
    }
    
    // For weights not available in Instrument Serif, use system font with weight
    static func fontWithSystemFallback(weight: Font.Weight, size: FontSize) -> Font {
        return Font.system(size: size.rawValue, weight: weight)
    }
    
    static func fontWithSystemFallback(weight: Font.Weight, size: CGFloat) -> Font {
        return Font.system(size: size, weight: weight)
    }
    
    static func uiFont(_ weight: FontWeight, size: FontSize) -> UIFont {
        return UIFont(name: weight.fontName, size: size.rawValue) ?? UIFont.systemFont(ofSize: size.rawValue)
    }
    
    static func uiFont(_ weight: FontWeight, size: CGFloat) -> UIFont {
        return UIFont(name: weight.fontName, size: size) ?? UIFont.systemFont(ofSize: size)
    }
    
    // MARK: - Fallback to System Fonts
    static func systemFontFallback(size: FontSize, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size.rawValue, weight: weight)
    }
    
    // MARK: - Font Registration Check
    static func printAvailableFonts() {
        print("Available Custom Fonts:")
        for familyName in UIFont.familyNames {
            if familyName.contains(customFontFamily) {
                print("Family: \(familyName)")
                for fontName in UIFont.fontNames(forFamilyName: familyName) {
                    print("  - \(fontName)")
                }
            }
        }
    }
    
    // MARK: - Dynamic Type Support
    static func scaledFont(_ weight: FontWeight, size: FontSize, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        return Font.custom(weight.fontName, size: size.rawValue, relativeTo: textStyle)
    }
}

// MARK: - SwiftUI View Extensions
extension View {
    func customFont(_ weight: FontManager.FontWeight, size: FontManager.FontSize) -> some View {
        self.font(FontManager.font(weight, size: size))
    }
    
    func customFont(_ weight: FontManager.FontWeight, size: CGFloat) -> some View {
        self.font(FontManager.font(weight, size: size))
    }
    
    func scaledCustomFont(_ weight: FontManager.FontWeight, size: FontManager.FontSize, relativeTo textStyle: Font.TextStyle = .body) -> some View {
        self.font(FontManager.scaledFont(weight, size: size, relativeTo: textStyle))
    }
    
    // Convenience methods for common font combinations
    func instrumentSerifRegular(size: FontManager.FontSize) -> some View {
        self.font(FontManager.font(.regular, size: size))
    }
    
    func instrumentSerifItalic(size: FontManager.FontSize) -> some View {
        self.font(FontManager.font(.italic, size: size))
    }
    
    // For weights not in Instrument Serif, use system font
    func systemFontWithWeight(_ weight: Font.Weight, size: FontManager.FontSize) -> some View {
        self.font(FontManager.fontWithSystemFallback(weight: weight, size: size))
    }
}
