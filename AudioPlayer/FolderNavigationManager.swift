//
//  FolderNavigationManager.swift
//  AudioPlayer
//
//  Created by Assistant on 2025/09/22.
//

import Foundation
import CoreData
import Combine

class FolderNavigationManager: ObservableObject {
    @Published var currentFolder: Folder? = nil
    @Published var navigationPath: [Folder] = []
    @Published var isInFolder: Bool = false
    
    // Navigate to a specific folder
    func navigateToFolder(_ folder: Folder) {
        // Add to navigation path if not already there
        if let lastFolder = navigationPath.last {
            if lastFolder != folder {
                navigationPath.append(folder)
            }
        } else {
            navigationPath.append(folder)
        }
        
        currentFolder = folder
        isInFolder = true
    }
    
    // Navigate back to parent folder
    func navigateBack() {
        guard !navigationPath.isEmpty else {
            // Already at root
            navigateToRoot()
            return
        }
        
        // Remove current folder from path
        navigationPath.removeLast()
        
        if let parentFolder = navigationPath.last {
            currentFolder = parentFolder
        } else {
            navigateToRoot()
        }
    }
    
    // Navigate to root (show all folders and loose files)
    func navigateToRoot() {
        currentFolder = nil
        navigationPath.removeAll()
        isInFolder = false
    }
    
    // Navigate to a specific level in the breadcrumb
    func navigateToLevel(_ level: Int) {
        guard level >= 0 && level < navigationPath.count else { return }
        
        if level == 0 {
            navigateToRoot()
        } else {
            // Keep only folders up to the specified level
            navigationPath = Array(navigationPath.prefix(level))
            currentFolder = navigationPath.last
            isInFolder = currentFolder != nil
        }
    }
    
    // Check if we can navigate back
    var canNavigateBack: Bool {
        return isInFolder
    }
    
    // Get breadcrumb titles for navigation
    var breadcrumbTitles: [String] {
        var titles = ["Library"]
        titles.append(contentsOf: navigationPath.map { $0.name })
        return titles
    }
    
    // Get current location description for accessibility
    var currentLocationDescription: String {
        if let currentFolder = currentFolder {
            return "Currently in folder: \(currentFolder.name)"
        } else {
            return "Currently in main library"
        }
    }
}

// Extension to handle Core Data operations
extension FolderNavigationManager {
    
    // Get folders for current navigation level
    func getFolders(context: NSManagedObjectContext) -> [Folder] {
        let request = Folder.fetchRequest()
        
        if let currentFolder = currentFolder {
            // Show subfolders of current folder
            request.predicate = NSPredicate(format: "parentFolder == %@", currentFolder)
        } else {
            // Show root-level folders (no parent)
            request.predicate = NSPredicate(format: "parentFolder == nil")
        }
        
        // Fetch without sorting - we'll sort naturally after fetching
        
        do {
            let folders = try context.fetch(request)
            // Sort naturally by folder name
            return folders.sorted { first, second in
                return first.name.isNaturallyLessThan(second.name)
            }
        } catch {
            print("Error fetching folders: \(error)")
            return []
        }
    }
    
    // Get audio files for current navigation level
    func getAudioFiles(context: NSManagedObjectContext) -> [AudioFile] {
        let request = AudioFile.fetchRequest()
        
        if let currentFolder = currentFolder {
            // Show files in current folder only
            request.predicate = NSPredicate(format: "folder == %@", currentFolder)
        } else {
            // Show files not in any folder (loose files) at root level
            request.predicate = NSPredicate(format: "folder == nil")
        }
        
        // Fetch without sorting - we'll sort naturally after fetching
        
        do {
            let files = try context.fetch(request)
            // Sort naturally by filename (without extension)
            return files.sorted { first, second in
                return first.displayNameForSorting.isNaturallyLessThan(second.displayNameForSorting)
            }
        } catch {
            print("Error fetching audio files: \(error)")
            return []
        }
    }
    
    // Delete a folder and all its contents
    func deleteFolder(_ folder: Folder, context: NSManagedObjectContext) {
        // Delete all audio files in the folder
        for audioFile in folder.audioFilesArray {
            // Delete physical files
            if let fileURL = audioFile.fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
            if let artworkURL = audioFile.artworkURL {
                try? FileManager.default.removeItem(at: artworkURL)
            }
            context.delete(audioFile)
        }
        
        // Recursively delete subfolders
        for subfolder in folder.subFoldersArray {
            deleteFolder(subfolder, context: context)
        }
        
        // Delete the folder itself
        context.delete(folder)
        
        // If we're currently in this folder or a subfolder, navigate back
        if currentFolder == folder || navigationPath.contains(folder) {
            navigateToRoot()
        }
        
        // Save context
        do {
            try context.save()
        } catch {
            print("Failed to delete folder: \(error)")
        }
    }
}