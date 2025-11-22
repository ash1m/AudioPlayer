//
//  FocusManagement.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/21.
//

import SwiftUI
import UIKit
import CoreData

// MARK: - Focus Management for VoiceOver

struct FocusManagementModifier: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let identifier: String
    let shouldFocus: Bool
    let announcement: String?
    
    init(identifier: String, shouldFocus: Bool = false, announcement: String? = nil) {
        self.identifier = identifier
        self.shouldFocus = shouldFocus
        self.announcement = announcement
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if shouldFocus && accessibilityManager.isVoiceOverRunning {
                    // Delay focus to ensure view is fully rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        accessibilityManager.announceLayoutChange()
                        
                        if let announcement = announcement {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                accessibilityManager.announceMessage(announcement)
                            }
                        }
                    }
                }
            }
    }
}

// MARK: - Smart Focus Management for Form Controls

struct SmartFocusManager: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @State private var hasFocused = false
    let focusOnError: Bool
    let errorMessage: String?
    
    init(focusOnError: Bool = false, errorMessage: String? = nil) {
        self.focusOnError = focusOnError
        self.errorMessage = errorMessage
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: errorMessage) { _, newErrorMessage in
                if focusOnError && newErrorMessage != nil && !hasFocused {
                    hasFocused = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        accessibilityManager.announceLayoutChange()
                        
                        if let error = newErrorMessage {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                accessibilityManager.announceMessage("Error: \(error)")
                            }
                        }
                    }
                }
            }
    }
}

// MARK: - Modal Presentation Focus Management

struct ModalFocusManager: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let modalTitle: String
    let isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, newValue in
                if newValue && accessibilityManager.isVoiceOverRunning {
                    // Announce modal presentation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        accessibilityManager.announceMessage("\(modalTitle) opened")
                        accessibilityManager.announceScreenChange()
                    }
                } else if !newValue && accessibilityManager.isVoiceOverRunning {
                    // Announce modal dismissal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        accessibilityManager.announceMessage("\(modalTitle) closed")
                        accessibilityManager.announceScreenChange()
                    }
                }
            }
    }
}

// MARK: - Tab Navigation Focus Management

struct TabFocusManager: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let tabName: String
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isActive) { _, newValue in
                if newValue && accessibilityManager.isVoiceOverRunning {
                    // Announce tab change with a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        accessibilityManager.announceMessage("\(tabName) tab selected")
                        accessibilityManager.announceScreenChange()
                    }
                }
            }
    }
}

// MARK: - Dynamic Content Focus Management

struct DynamicContentFocusManager: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let contentDescription: String
    let hasContent: Bool
    let emptyStateMessage: String?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: hasContent) { _, newValue in
                if accessibilityManager.isVoiceOverRunning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if newValue {
                            accessibilityManager.announceMessage("\(contentDescription) loaded")
                        } else if let emptyMessage = emptyStateMessage {
                            accessibilityManager.announceMessage(emptyMessage)
                        }
                        accessibilityManager.announceLayoutChange()
                    }
                }
            }
    }
}

// MARK: - Action Completion Focus Management

struct ActionFeedbackManager: ViewModifier {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    let actionName: String
    let isCompleted: Bool
    let successMessage: String?
    let failureMessage: String?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isCompleted) { _, completed in
                if accessibilityManager.isVoiceOverRunning && completed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let message = successMessage ?? "\(actionName) completed"
                        accessibilityManager.announceMessage(message)
                    }
                }
            }
    }
}

// MARK: - View Extensions for Easy Focus Management

extension View {
    /// Manages focus for this view with optional announcement
    func focusManagement(identifier: String, shouldFocus: Bool = false, announcement: String? = nil) -> some View {
        modifier(FocusManagementModifier(identifier: identifier, shouldFocus: shouldFocus, announcement: announcement))
    }
    
    /// Smart focus management for form controls with error handling
    func smartFocus(onError: Bool = false, errorMessage: String? = nil) -> some View {
        modifier(SmartFocusManager(focusOnError: onError, errorMessage: errorMessage))
    }
    
    /// Focus management for modal presentations
    func modalFocus(title: String, isPresented: Bool) -> some View {
        modifier(ModalFocusManager(modalTitle: title, isPresented: isPresented))
    }
    
    /// Focus management for tab navigation
    func tabFocus(name: String, isActive: Bool) -> some View {
        modifier(TabFocusManager(tabName: name, isActive: isActive))
    }
    
    /// Focus management for dynamic content loading
    func dynamicContentFocus(description: String, hasContent: Bool, emptyMessage: String? = nil) -> some View {
        modifier(DynamicContentFocusManager(
            contentDescription: description,
            hasContent: hasContent,
            emptyStateMessage: emptyMessage
        ))
    }
    
    /// Provides feedback for completed actions
    func actionFeedback(name: String, isCompleted: Bool, success: String? = nil, failure: String? = nil) -> some View {
        modifier(ActionFeedbackManager(
            actionName: name,
            isCompleted: isCompleted,
            successMessage: success,
            failureMessage: failure
        ))
    }
}

// MARK: - Screen Reader Navigation Helpers

extension AccessibilityManager {
    
    /// Announce navigation between major sections
    func announceSectionChange(from: String, to: String) {
        guard isVoiceOverRunning else { return }
        
        announceMessage("Navigated from \(from) to \(to)")
        announceScreenChange()
    }
    
    /// Announce list updates with proper context
    func announceListUpdate(description: String, itemCount: Int, selectedIndex: Int? = nil) {
        guard isVoiceOverRunning else { return }
        
        var announcement = "\(description): \(itemCount) item\(itemCount == 1 ? "" : "s")"
        
        if let selected = selectedIndex {
            announcement += ". Item \(selected + 1) of \(itemCount) selected"
        }
        
        announceMessage(announcement)
        announceLayoutChange()
    }
    
    /// Announce search results
    func announceSearchResults(query: String, resultCount: Int) {
        guard isVoiceOverRunning else { return }
        
        let announcement = resultCount == 0 ? 
            "No results found for \(query)" :
            "Found \(resultCount) result\(resultCount == 1 ? "" : "s") for \(query)"
        
        announceMessage(announcement)
        announceLayoutChange()
    }
    
    /// Announce loading states
    func announceLoadingState(_ state: LoadingState, context: String = "") {
        guard isVoiceOverRunning else { return }
        
        let contextPrefix = context.isEmpty ? "" : "\(context): "
        
        switch state {
        case .loading:
            announceMessage("\(contextPrefix)Loading")
        case .success:
            announceMessage("\(contextPrefix)Loaded successfully")
        case .failure(let error):
            announceMessage("\(contextPrefix)Failed to load. \(error)")
        case .empty:
            announceMessage("\(contextPrefix)No content available")
        }
    }
}

// MARK: - Loading State Enum

enum LoadingState {
    case loading
    case success
    case failure(String)
    case empty
}