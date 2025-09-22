//
//  FolderCardView.swift
//  AudioPlayer
//
//  Created by Assistant on 2025/09/22.
//

import SwiftUI
import CoreData

struct FolderGridCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    let folder: Folder
    let action: () -> Void
    let onDelete: (Folder) -> Void
    
    // Calculate responsive card width based on device and text size
    private var cardWidth: CGFloat {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return 200
        case .xLarge, .xxLarge, .xxxLarge:
            return 160
        case .large:
            return 140
        default:
            return 120
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Square folder icon area that touches top and side edges
                GeometryReader { geometry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [
                                    accessibilityManager.highContrastColor(base: .orange.opacity(0.3), highContrast: .gray.opacity(0.5)),
                                    accessibilityManager.highContrastColor(base: .yellow.opacity(0.3), highContrast: .gray.opacity(0.7))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: geometry.size.width, height: geometry.size.width)
                        
                        // Folder icon with folder.fill symbol
                        Image(systemName: "folder.fill")
                            .font(dynamicTypeSize.isLargeSize ? .title : .largeTitle)
                            .foregroundColor(.orange)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                        
                        // File count badge in top right
                        if folder.fileCount > 0 {
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("\(folder.fileCount)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                        .padding(.trailing, 8)
                                        .padding(.top, 8)
                                }
                                Spacer()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.width)
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                
                // Text content area
                VStack(alignment: .leading, spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
                    Text(folder.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .visualAccessibility()
                    
                    Text("\(folder.fileCount) file\(folder.fileCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .visualAccessibility(foreground: .secondary)
                }
                .padding(.horizontal, AccessibleSpacing.compact(for: dynamicTypeSize))
                .padding(.bottom, AccessibleSpacing.compact(for: dynamicTypeSize))
                .padding(.top, AccessibleSpacing.compact(for: dynamicTypeSize))
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .contentShape(Rectangle())
            .layoutPriority(1) // High priority to maintain size
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: {
                onDelete(folder)
            }) {
                Label("Delete Folder", systemImage: "trash")
            }
        }
        .accessibilityLabel(folderAccessibilityLabel)
        .accessibilityHint(folderAccessibilityHint)
        .accessibilityValue(folderAccessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibleTouchTarget()
        .visualAccessibility(reducedMotion: true)
    }
    
    // MARK: - Computed Properties for Accessibility
    
    private var folderAccessibilityLabel: String {
        return "Folder: \(folder.name)"
    }
    
    private var folderAccessibilityHint: String {
        return "Double tap to open folder"
    }
    
    private var folderAccessibilityValue: String {
        let fileCountText = folder.fileCount == 1 ? "1 file" : "\(folder.fileCount) files"
        return "Contains \(fileCountText)"
    }
    
}

struct FolderListCard: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    let folder: Folder
    let action: () -> Void
    let onDelete: (Folder) -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AccessibleSpacing.standard(for: dynamicTypeSize)) {
                folderIconView
                folderContentView
                chevronView
            }
            .frame(height: 80)
            .padding(.vertical, AccessibleSpacing.compact(for: dynamicTypeSize))
            .padding(.horizontal, 12)
            .background(backgroundView)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: {
                onDelete(folder)
            }) {
                Label("Delete Folder", systemImage: "trash")
            }
        }
        .accessibilityLabel(folderAccessibilityLabel)
        .accessibilityHint(folderAccessibilityHint)
        .accessibilityValue(folderAccessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibleTouchTarget()
        .visualAccessibility(reducedMotion: true)
    }
    
    // MARK: - Computed Properties for Accessibility
    
    private var folderAccessibilityLabel: String {
        return "Folder: \(folder.name)"
    }
    
    private var folderAccessibilityHint: String {
        return "Double tap to open folder"
    }
    
    private var folderAccessibilityValue: String {
        let fileCountText = folder.fileCount == 1 ? "1 file" : "\(folder.fileCount) files"
        return "Contains \(fileCountText)"
    }
    
    // MARK: - Component Views
    
    private var folderIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [
                        accessibilityManager.highContrastColor(base: .orange.opacity(0.3), highContrast: .gray.opacity(0.5)),
                        accessibilityManager.highContrastColor(base: .yellow.opacity(0.3), highContrast: .gray.opacity(0.7))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)
            
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            // File count badge
            if folder.fileCount > 0 {
                VStack {
                    HStack {
                        Spacer()
                        Text("\(folder.fileCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .frame(width: 60, height: 60)
                .padding(4)
            }
        }
    }
    
    private var folderContentView: some View {
        VStack(alignment: .leading, spacing: AccessibleSpacing.compact(for: dynamicTypeSize)) {
            Text(folder.name)
                .dynamicTypeSupport(.headline, maxSize: .accessibility2, lineLimit: 2, allowsTightening: true)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .visualAccessibility()
            
            Text("\(folder.fileCount) file\(folder.fileCount == 1 ? "" : "s")")
                .dynamicTypeSupport(.caption, maxSize: .accessibility1, lineLimit: 1)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .visualAccessibility(foreground: .secondary)
            
            // Show folder path if it's not root
            if folder.path != "/" && !folder.path.isEmpty {
                Text(folder.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var chevronView: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.trailing, 4)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleFolder = Folder(context: context, name: "Sample Folder", path: "/sample")
    sampleFolder.fileCount = 5
    
    return VStack {
        FolderGridCard(
            folder: sampleFolder,
            action: {},
            onDelete: { _ in }
        )
        .frame(width: 140, height: 180)
        
        FolderListCard(
            folder: sampleFolder,
            action: {},
            onDelete: { _ in }
        )
    }
    .environmentObject(AccessibilityManager())
    .padding()
}