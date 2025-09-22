//
//  DynamicTypeSupport.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/17.
//

import SwiftUI

// MARK: - Dynamic Type View Modifier

struct DynamicTypeSupport: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    let style: Font.TextStyle
    let maxSize: DynamicTypeSize
    let lineLimit: Int?
    let allowsTightening: Bool
    
    init(style: Font.TextStyle, maxSize: DynamicTypeSize = .accessibility5, lineLimit: Int? = nil, allowsTightening: Bool = true) {
        self.style = style
        self.maxSize = maxSize
        self.lineLimit = lineLimit
        self.allowsTightening = allowsTightening
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(style, design: .default))
            .dynamicTypeSize(...maxSize)
            .lineLimit(lineLimit)
            .allowsTightening(allowsTightening)
            .minimumScaleFactor(accessibilityManager.isLargeTextEnabled ? 0.8 : 0.9)
    }
}

// MARK: - Adaptive Layout Modifier

struct AdaptiveLayout: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    let compactThreshold: DynamicTypeSize
    let spacing: CGFloat
    
    init(compactThreshold: DynamicTypeSize = .large, spacing: CGFloat = 8) {
        self.compactThreshold = compactThreshold
        self.spacing = spacing
    }
    
    func body(content: Content) -> some View {
        if dynamicTypeSize == compactThreshold || dynamicTypeSize.isLargeSize || accessibilityManager.isLargeTextEnabled {
            VStack(spacing: spacing) {
                content
            }
        } else {
            HStack(spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - Accessible Touch Target Modifier

struct AccessibleTouchTarget: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    let minSize: CGSize
    
    init(minSize: CGSize = CGSize(width: 44, height: 44)) {
        self.minSize = minSize
    }
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize.width, minHeight: minSize.height)
            .contentShape(Rectangle())
    }
}

// MARK: - Visual Accessibility Modifier

struct VisualAccessibility: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    let foregroundColor: Color
    let backgroundColor: Color?
    let reducedMotion: Bool
    
    init(foregroundColor: Color = .primary, backgroundColor: Color? = nil, reducedMotion: Bool = true) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.reducedMotion = reducedMotion
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(accessibilityManager.accessibleColor(foreground: foregroundColor, background: backgroundColor ?? .clear))
            .background(
                backgroundColor?
                    .opacity(accessibilityManager.isReduceTransparencyEnabled ? 1.0 : 0.8)
            )
            .animation(
                accessibilityManager.isReduceMotionEnabled && reducedMotion ? .none : .default,
                value: accessibilityManager.isReduceMotionEnabled
            )
    }
}

// MARK: - High Contrast Modifier

struct HighContrastSupport: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    let normalColor: Color
    let highContrastColor: Color
    
    init(normal: Color, highContrast: Color) {
        self.normalColor = normal
        self.highContrastColor = highContrast
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(accessibilityManager.highContrastColor(base: normalColor, highContrast: highContrastColor))
    }
}

// MARK: - View Extensions

extension View {
    func dynamicTypeSupport(_ style: Font.TextStyle, maxSize: DynamicTypeSize = .accessibility5, lineLimit: Int? = nil, allowsTightening: Bool = true) -> some View {
        modifier(DynamicTypeSupport(style: style, maxSize: maxSize, lineLimit: lineLimit, allowsTightening: allowsTightening))
    }
    
    func adaptiveLayout(compactThreshold: DynamicTypeSize = .large, spacing: CGFloat = 8) -> some View {
        modifier(AdaptiveLayout(compactThreshold: compactThreshold, spacing: spacing))
    }
    
    func accessibleTouchTarget(minSize: CGSize = CGSize(width: 44, height: 44)) -> some View {
        modifier(AccessibleTouchTarget(minSize: minSize))
    }
    
    func visualAccessibility(foreground: Color = .primary, background: Color? = nil, reducedMotion: Bool = true) -> some View {
        modifier(VisualAccessibility(foregroundColor: foreground, backgroundColor: background, reducedMotion: reducedMotion))
    }
    
    func highContrastSupport(normal: Color, highContrast: Color) -> some View {
        modifier(HighContrastSupport(normal: normal, highContrast: highContrast))
    }
}

// MARK: - Accessibility-Aware Spacing

struct AccessibleSpacing {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    static func standard(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 8
        case .medium, .large:
            return 12
        case .xLarge, .xxLarge:
            return 16
        case .xxxLarge:
            return 20
        case .accessibility1, .accessibility2:
            return 24
        case .accessibility3, .accessibility4:
            return 28
        case .accessibility5:
            return 32
        @unknown default:
            return 12
        }
    }
    
    static func compact(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        return standard(for: dynamicTypeSize) * 0.5
    }
    
    static func expanded(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        return standard(for: dynamicTypeSize) * 1.5
    }
}

// MARK: - Accessibility-Aware Padding

extension View {
    func accessiblePadding(_ edges: Edge.Set = .all, dynamicTypeSize: DynamicTypeSize = .medium) -> some View {
        padding(edges, AccessibleSpacing.standard(for: dynamicTypeSize))
    }
    
    func compactAccessiblePadding(_ edges: Edge.Set = .all, dynamicTypeSize: DynamicTypeSize = .medium) -> some View {
        padding(edges, AccessibleSpacing.compact(for: dynamicTypeSize))
    }
    
    func expandedAccessiblePadding(_ edges: Edge.Set = .all, dynamicTypeSize: DynamicTypeSize = .medium) -> some View {
        padding(edges, AccessibleSpacing.expanded(for: dynamicTypeSize))
    }
}

// MARK: - Dynamic Type Size Utilities

extension DynamicTypeSize {
    var isAccessibilitySize: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
    
    var isLargeSize: Bool {
        switch self {
        case .xLarge, .xxLarge, .xxxLarge, .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
}
