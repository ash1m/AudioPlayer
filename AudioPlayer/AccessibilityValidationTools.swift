//
//  AccessibilityValidationTools.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/17.
//

import SwiftUI
import UIKit
import Combine

#if DEBUG
/// Runtime accessibility validation tools for continuous compliance monitoring
class AccessibilityValidationTools: ObservableObject {
    
    // MARK: - Validation State
    
    @Published private(set) var isValidating = false
    @Published private(set) var validationResults: [ValidationResult] = []
    @Published private(set) var continuousValidationEnabled = false
    
    // MARK: - Validation Configuration
    
    struct ValidationConfig {
        var validateLabels = true
        var validateTouchTargets = true
        var validateTraits = true
        var validateContrast = false  // Requires visual analysis
        var validateFocusOrder = true
        var logViolations = true
        var breakOnCriticalIssues = false
    }
    
    private var config = ValidationConfig()
    
    // MARK: - Validation Results
    
    struct ValidationResult {
        let timestamp: Date
        let elementPath: String
        let issue: AccessibilityIssue
        let severity: Severity
        let suggestion: String
        
        enum Severity {
            case critical, warning, info
            
            var emoji: String {
                switch self {
                case .critical: return "🚨"
                case .warning: return "⚠️"
                case .info: return "ℹ️"
                }
            }
        }
    }
    
    // MARK: - Accessibility Issues
    
    enum AccessibilityIssue {
        case missingLabel
        case emptyLabel
        case poorLabel(String)
        case missingTrait
        case incorrectTrait
        case smallTouchTarget(CGSize)
        case duplicateLabel(String)
        case missingHint
        case poorFocusOrder
        case inaccessibleElement
        case missingValue
        
        var description: String {
            switch self {
            case .missingLabel:
                return "Element missing accessibility label"
            case .emptyLabel:
                return "Element has empty accessibility label"
            case .poorLabel(let label):
                return "Poor accessibility label: '\(label)'"
            case .missingTrait:
                return "Element missing appropriate accessibility traits"
            case .incorrectTrait:
                return "Element has incorrect accessibility traits"
            case .smallTouchTarget(let size):
                return "Touch target too small: \(Int(size.width))x\(Int(size.height))pt (minimum: 44x44pt)"
            case .duplicateLabel(let label):
                return "Duplicate accessibility label: '\(label)'"
            case .missingHint:
                return "Complex element missing accessibility hint"
            case .poorFocusOrder:
                return "Element not in logical focus order"
            case .inaccessibleElement:
                return "Element not accessible to assistive technologies"
            case .missingValue:
                return "Adjustable element missing accessibility value"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupValidationObservers()
    }
    
    // MARK: - Public API
    
    /// Start continuous accessibility validation
    func startContinuousValidation() {
        continuousValidationEnabled = true
        performValidationCycle()
    }
    
    /// Stop continuous accessibility validation
    func stopContinuousValidation() {
        continuousValidationEnabled = false
    }
    
    /// Perform one-time validation of current view hierarchy
    func validateCurrentView() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootView = window.rootViewController?.view else {
            print("⚠️ AccessibilityValidationTools: No root view found")
            return
        }
        
        Task {
            await performValidation(on: rootView)
        }
    }
    
    /// Validate specific view
    func validate(view: UIView) async {
        await performValidation(on: view)
    }
    
    // MARK: - Validation Logic
    
    private func performValidationCycle() {
        guard continuousValidationEnabled else { return }
        
        validateCurrentView()
        
        // Schedule next validation cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.performValidationCycle()
        }
    }
    
    private func performValidation(on rootView: UIView) async {
        await MainActor.run {
            isValidating = true
        }
        
        var newResults: [ValidationResult] = []
        let accessibleElements = findAllElements(in: rootView)
        
        if config.validateLabels {
            newResults.append(contentsOf: validateLabels(in: accessibleElements))
        }
        
        if config.validateTouchTargets {
            newResults.append(contentsOf: validateTouchTargets(in: accessibleElements))
        }
        
        if config.validateTraits {
            newResults.append(contentsOf: validateTraits(in: accessibleElements))
        }
        
        if config.validateFocusOrder {
            newResults.append(contentsOf: validateFocusOrder(in: accessibleElements))
        }
        
        await MainActor.run {
            validationResults = newResults
            isValidating = false
            
            if config.logViolations {
                logValidationResults(newResults)
            }
            
            if config.breakOnCriticalIssues {
                handleCriticalIssues(newResults)
            }
        }
    }
    
    // MARK: - Specific Validation Methods
    
    private func validateLabels(in elements: [(UIView, String)]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        var seenLabels: Set<String> = []
        
        for (element, path) in elements {
            guard element.isAccessibilityElement else { continue }
            
            let label = element.accessibilityLabel
            
            // Check for missing label
            if label == nil || label!.isEmpty {
                // Allow certain elements to not have labels (decorative images, etc.)
                if !shouldRequireLabel(for: element) {
                    continue
                }
                
                results.append(ValidationResult(
                    timestamp: Date(),
                    elementPath: path,
                    issue: label == nil ? .missingLabel : .emptyLabel,
                    severity: .critical,
                    suggestion: "Add descriptive accessibility label"
                ))
                continue
            }
            
            let labelText = label!
            
            // Check for duplicate labels
            if seenLabels.contains(labelText) {
                results.append(ValidationResult(
                    timestamp: Date(),
                    elementPath: path,
                    issue: .duplicateLabel(labelText),
                    severity: .warning,
                    suggestion: "Make label unique or group related elements"
                ))
            } else {
                seenLabels.insert(labelText)
            }
            
            // Check for poor label quality
            if isPoorLabel(labelText) {
                results.append(ValidationResult(
                    timestamp: Date(),
                    elementPath: path,
                    issue: .poorLabel(labelText),
                    severity: .warning,
                    suggestion: "Improve label to be more descriptive"
                ))
            }
        }
        
        return results
    }
    
    private func validateTouchTargets(in elements: [(UIView, String)]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        let minimumSize: CGFloat = 44.0
        
        for (element, path) in elements {
            guard isInteractiveElement(element) else { continue }
            
            let size = element.frame.size
            
            if size.width < minimumSize || size.height < minimumSize {
                results.append(ValidationResult(
                    timestamp: Date(),
                    elementPath: path,
                    issue: .smallTouchTarget(size),
                    severity: .critical,
                    suggestion: "Increase touch target to at least 44x44 points"
                ))
            }
        }
        
        return results
    }
    
    private func validateTraits(in elements: [(UIView, String)]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        for (element, path) in elements {
            guard element.isAccessibilityElement else { continue }
            
            let traits = element.accessibilityTraits
            
            // Check for missing traits
            if traits.isEmpty {
                if isInteractiveElement(element) {
                    results.append(ValidationResult(
                        timestamp: Date(),
                        elementPath: path,
                        issue: .missingTrait,
                        severity: .warning,
                        suggestion: "Add appropriate accessibility traits (button, adjustable, etc.)"
                    ))
                }
                continue
            }
            
            // Check for incorrect traits
            if let incorrectTrait = validateElementTraits(element: element, traits: traits) {
                results.append(ValidationResult(
                    timestamp: Date(),
                    elementPath: path,
                    issue: .incorrectTrait,
                    severity: .warning,
                    suggestion: incorrectTrait
                ))
            }
            
            // Check for missing hints on complex controls
            if traits.contains(.adjustable) && element.accessibilityHint?.isEmpty != false {
                results.append(ValidationResult(
                    timestamp: Date(),
                    elementPath: path,
                    issue: .missingHint,
                    severity: .warning,
                    suggestion: "Add accessibility hint explaining how to use adjustable element"
                ))
            }
            
            // Check for missing values on adjustable elements
            if traits.contains(.adjustable) && element.accessibilityValue?.isEmpty != false {
                results.append(ValidationResult(
                    timestamp: Date(),
                    elementPath: path,
                    issue: .missingValue,
                    severity: .warning,
                    suggestion: "Add accessibility value showing current state"
                ))
            }
        }
        
        return results
    }
    
    private func validateFocusOrder(in elements: [(UIView, String)]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // Basic focus order validation - check if elements are in roughly reading order
        let accessibleElements = elements
            .filter { $0.0.isAccessibilityElement }
            .sorted { element1, element2 in
                let frame1 = element1.0.frame
                let frame2 = element2.0.frame
                
                // Sort by Y position first, then X position
                if abs(frame1.minY - frame2.minY) > 10 {
                    return frame1.minY < frame2.minY
                } else {
                    return frame1.minX < frame2.minX
                }
            }
        
        // Check for elements that are significantly out of order
        for (index, (element, path)) in accessibleElements.enumerated() {
            if index > 0 {
                let previousElement = accessibleElements[index - 1].0
                let currentFrame = element.frame
                let previousFrame = previousElement.frame
                
                // If current element is significantly above the previous element, it might be out of order
                if currentFrame.maxY < previousFrame.minY - 20 {
                    results.append(ValidationResult(
                        timestamp: Date(),
                        elementPath: path,
                        issue: .poorFocusOrder,
                        severity: .info,
                        suggestion: "Consider adjusting element order for better focus flow"
                    ))
                }
            }
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    private func findAllElements(in view: UIView) -> [(UIView, String)] {
        var elements: [(UIView, String)] = []
        
        func traverse(_ currentView: UIView, path: String) {
            let viewName = String(describing: type(of: currentView))
            let currentPath = path.isEmpty ? viewName : "\(path) > \(viewName)"
            
            elements.append((currentView, currentPath))
            
            for (index, subview) in currentView.subviews.enumerated() {
                traverse(subview, path: "\(currentPath)[\(index)]")
            }
        }
        
        traverse(view, path: "")
        return elements
    }
    
    private func shouldRequireLabel(for element: UIView) -> Bool {
        // Elements that typically don't need labels
        if element.accessibilityTraits.contains(.image) && !element.accessibilityTraits.contains(.button) {
            return false
        }
        
        // Decorative elements
        if element.accessibilityElementsHidden {
            return false
        }
        
        // Interactive elements always need labels
        if isInteractiveElement(element) {
            return true
        }
        
        // Text elements should have labels if they contain meaningful content
        return element.accessibilityTraits.contains(.staticText)
    }
    
    private func isInteractiveElement(_ element: UIView) -> Bool {
        return element.accessibilityTraits.contains(.button) ||
               element.accessibilityTraits.contains(.adjustable) ||
               element.accessibilityTraits.contains(.link) ||
               element is UIControl
    }
    
    private func isPoorLabel(_ label: String) -> Bool {
        // Check for obviously poor labels
        let poorLabels = ["button", "image", "view", "label", "text", "control"]
        let lowercaseLabel = label.lowercased()
        
        return poorLabels.contains { poorLabel in
            lowercaseLabel.contains(poorLabel) && label.count <= poorLabel.count + 2
        }
    }
    
    private func validateElementTraits(element: UIView, traits: UIAccessibilityTraits) -> String? {
        // Validate that traits match element type and purpose
        
        if let button = element as? UIButton, !traits.contains(.button) {
            return "UIButton should have .button trait"
        }
        
        if let slider = element as? UISlider, !traits.contains(.adjustable) {
            return "UISlider should have .adjustable trait"
        }
        
        if let textField = element as? UITextField {
            if !traits.contains(.allowsDirectInteraction) && textField.isEditable {
                return "Editable text field should allow direct interaction"
            }
        }
        
        return nil
    }
    
    private func setupValidationObservers() {
        // Observe view hierarchy changes for continuous validation
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.continuousValidationEnabled == true {
                self?.validateCurrentView()
            }
        }
    }
    
    // MARK: - Reporting and Logging
    
    private func logValidationResults(_ results: [ValidationResult]) {
        guard !results.isEmpty else { return }
        
        print("🔍 Accessibility Validation Results:")
        print("====================================")
        
        let groupedResults = Dictionary(grouping: results) { $0.severity }
        
        for severity in [ValidationResult.Severity.critical, .warning, .info] {
            guard let issuesForSeverity = groupedResults[severity], !issuesForSeverity.isEmpty else { continue }
            
            print("\n\(severity.emoji) \(severity) Issues (\(issuesForSeverity.count)):")
            print(String(repeating: "-", count: 40))
            
            for result in issuesForSeverity {
                print("• \(result.issue.description)")
                print("  Path: \(result.elementPath)")
                print("  Suggestion: \(result.suggestion)")
                print()
            }
        }
        
        print("====================================")
    }
    
    private func handleCriticalIssues(_ results: [ValidationResult]) {
        let criticalIssues = results.filter { $0.severity == .critical }
        
        if !criticalIssues.isEmpty {
            print("🚨 CRITICAL ACCESSIBILITY ISSUES DETECTED!")
            print("Consider fixing these issues before release:")
            
            for issue in criticalIssues {
                print("• \(issue.issue.description) at \(issue.elementPath)")
            }
            
            // In development, you might want to show an alert or assertion
            #if DEBUG
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let topViewController = window.rootViewController else {
                    return
                }
                
                let alert = UIAlertController(
                    title: L("validation.critical.alert.title"),
                    message: L("validation.critical.alert.message", criticalIssues.count),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: L("validation.ok"), style: .default))
                topViewController.present(alert, animated: true)
            }
            #endif
        }
    }
    
    // MARK: - Configuration
    
    func updateConfig(_ newConfig: ValidationConfig) {
        config = newConfig
    }
    
    func getValidationSummary() -> (critical: Int, warning: Int, info: Int) {
        let groupedResults = Dictionary(grouping: validationResults) { $0.severity }
        
        return (
            critical: groupedResults[.critical]?.count ?? 0,
            warning: groupedResults[.warning]?.count ?? 0,
            info: groupedResults[.info]?.count ?? 0
        )
    }
}

// MARK: - SwiftUI Integration

struct AccessibilityValidationOverlay: View {
    @StateObject private var validator = AccessibilityValidationTools()
    @State private var showingResults = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 4) {
                    Button(action: {
                        showingResults.toggle()
                    }) {
                        let summary = validator.getValidationSummary()
                        let totalIssues = summary.critical + summary.warning + summary.info
                        
                        VStack(spacing: 2) {
                            Image(systemName: "eye.circle.fill")
                                .foregroundColor(summary.critical > 0 ? .red : 
                                               summary.warning > 0 ? .orange : .green)
                            
                            if totalIssues > 0 {
                                Text("\(totalIssues)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    
                    // Continuous validation toggle
                    Button(action: {
                        if validator.continuousValidationEnabled {
                            validator.stopContinuousValidation()
                        } else {
                            validator.startContinuousValidation()
                        }
                    }) {
                        Image(systemName: validator.continuousValidationEnabled ? "pause.circle.fill" : "play.circle.fill")
                            .foregroundColor(validator.continuousValidationEnabled ? .orange : .gray)
                    }
                    .font(.caption)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
            }
            .padding(.trailing)
            
            Spacer()
        }
        .sheet(isPresented: $showingResults) {
            AccessibilityValidationResultsView(validator: validator)
        }
        .onAppear {
            validator.validateCurrentView()
        }
    }
}

struct AccessibilityValidationResultsView: View {
    @ObservedObject var validator: AccessibilityValidationTools
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    let summary = validator.getValidationSummary()
                    
                    if summary.critical > 0 {
                        Label(L("test.suite.critical.issues", summary.critical), systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                    
                    if summary.warning > 0 {
                        Label(L("test.suite.warnings", summary.warning), systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }
                    
                    if summary.info > 0 {
                        Label(L("test.suite.suggestions", summary.info), systemImage: "info.circle")
                            .foregroundColor(.blue)
                    }
                    
                    if summary.critical == 0 && summary.warning == 0 && summary.info == 0 {
                        Label(L("test.suite.no.issues"), systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                if !validator.validationResults.isEmpty {
                    Section("Issues") {
                        ForEach(validator.validationResults.indices, id: \.self) { index in
                            let result = validator.validationResults[index]
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(result.severity.emoji)
                                    Text(result.issue.description)
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                Text(result.elementPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(result.suggestion)
                                    .font(.callout)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(L("validation.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("test.suite.refresh")) {
                        validator.validateCurrentView()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("action.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#endif

// MARK: - Extension for Easy Integration

extension View {
    /// Add accessibility validation overlay in debug builds
    func accessibilityValidationOverlay() -> some View {
        #if DEBUG
        return self.overlay(alignment: .topTrailing) {
            AccessibilityValidationOverlay()
        }
        #else
        return self
        #endif
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview {
    VStack {
        Text("Sample Content")
        Button("Test Button") {
            // Test action
        }
        Slider(value: .constant(0.5))
    }
    .accessibilityValidationOverlay()
}
#endif