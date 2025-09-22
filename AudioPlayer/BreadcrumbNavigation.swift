//
//  BreadcrumbNavigation.swift
//  AudioPlayer
//
//  Created by Assistant on 2025/09/22.
//

import SwiftUI
import CoreData

struct BreadcrumbNavigation: View {
    @ObservedObject var folderNavigationManager: FolderNavigationManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // Back button
            Button(action: {
                let parentName = folderNavigationManager.navigationPath.count > 1 ? 
                    folderNavigationManager.navigationPath[folderNavigationManager.navigationPath.count - 2].name : nil
                folderNavigationManager.navigateBack()
                accessibilityManager.announceReturnToParent(parentName: parentName)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                    Text("Back")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go back to parent folder")
            .accessibilityHint("Double tap to navigate back")
            
            Spacer()
            
            // Breadcrumb trail
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(folderNavigationManager.breadcrumbTitles.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 4) {
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if index == folderNavigationManager.breadcrumbTitles.count - 1 {
                                // Current location - not clickable
                                Text(title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            } else {
                                // Clickable breadcrumb
                                Button(action: {
                                    if index == 0 {
                                        accessibilityManager.announceReturnToLibrary()
                                    } else {
                                        accessibilityManager.announceReturnToParent(parentName: title)
                                    }
                                    folderNavigationManager.navigateToLevel(index)
                                }) {
                                    Text(title)
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Navigate to \(title)")
                                .accessibilityHint("Double tap to go to \(title)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 30)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Breadcrumb navigation")
        .accessibilityValue(folderNavigationManager.currentLocationDescription)
    }
}

#Preview {
    let navigationManager = FolderNavigationManager()
    // Simulate being in a nested folder
    let context = PersistenceController.preview.container.viewContext
    let rootFolder = Folder(context: context, name: "Music", path: "/Music")
    let subFolder = Folder(context: context, name: "Albums", path: "/Music/Albums", parentFolder: rootFolder)
    
    navigationManager.navigateToFolder(rootFolder)
    navigationManager.navigateToFolder(subFolder)
    
    return BreadcrumbNavigation(folderNavigationManager: navigationManager)
        .padding()
}