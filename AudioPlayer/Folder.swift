//
//  Folder.swift
//  AudioPlayer
//
//  Created by Assistant on 2025/09/22.
//

import Foundation
import CoreData

@objc(Folder)
class Folder: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }

    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var path: String
    @NSManaged var dateAdded: Date
    @NSManaged var fileCount: Int32
    @NSManaged var lastPlayedPosition: Double
    @NSManaged var lastPlayedDate: Date?
    @NSManaged var audioFiles: NSSet?
    @NSManaged var lastPlayedAudioFile: AudioFile?
    @NSManaged var parentFolder: Folder?
    @NSManaged var subFolders: NSSet?
    
    // Convenience initializer
    convenience init(context: NSManagedObjectContext, 
                    name: String,
                    path: String,
                    parentFolder: Folder? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.path = path
        self.dateAdded = Date()
        self.fileCount = 0
        self.lastPlayedPosition = 0.0
        self.lastPlayedDate = nil
        self.lastPlayedAudioFile = nil
        self.parentFolder = parentFolder
    }
    
    // Computed properties
    var audioFilesArray: [AudioFile] {
        let set = audioFiles as? Set<AudioFile> ?? []
        return Array(set).sorted { first, second in
            return first.displayNameForSorting.isNaturallyLessThan(second.displayNameForSorting)
        }
    }
    
    var subFoldersArray: [Folder] {
        let set = subFolders as? Set<Folder> ?? []
        return Array(set).sorted { first, second in
            return first.name.isNaturallyLessThan(second.name)
        }
    }
    
    // Update file count
    func updateFileCount() {
        let directFileCount = Int32(audioFilesArray.count)
        let subfolderFileCount = subFoldersArray.reduce(0) { total, subfolder in
            return total + subfolder.fileCount
        }
        self.fileCount = directFileCount + subfolderFileCount
    }
    
    // MARK: - Playback State Management
    
    /// Check if this folder has saved playback state
    var hasPlaybackState: Bool {
        return lastPlayedAudioFile != nil && lastPlayedDate != nil
    }
    
    /// Get the progress percentage through the folder (0.0 to 1.0)
    var playbackProgress: Double {
        guard let lastFile = lastPlayedAudioFile else { return 0.0 }
        
        let orderedFiles = audioFilesArray
        guard let fileIndex = orderedFiles.firstIndex(of: lastFile), !orderedFiles.isEmpty else { return 0.0 }
        
        let fileProgress = lastFile.duration > 0 ? lastPlayedPosition / lastFile.duration : 0.0
        let overallProgress = (Double(fileIndex) + fileProgress) / Double(orderedFiles.count)
        
        return min(max(overallProgress, 0.0), 1.0)
    }
    
    /// Save the current playback state for this folder
    func savePlaybackState(audioFile: AudioFile, position: Double) {
        self.lastPlayedAudioFile = audioFile
        self.lastPlayedPosition = position
        self.lastPlayedDate = Date()
    }
    
    /// Clear the saved playback state
    func clearPlaybackState() {
        self.lastPlayedAudioFile = nil
        self.lastPlayedPosition = 0.0
        self.lastPlayedDate = nil
    }
    
    /// Get the audio file to resume from (either the last played file or the first file)
    func getResumeAudioFile() -> AudioFile? {
        if let lastFile = lastPlayedAudioFile, audioFilesArray.contains(lastFile) {
            return lastFile
        }
        return audioFilesArray.first
    }
    
    /// Get the position to resume from
    func getResumePosition() -> Double {
        return lastPlayedPosition
    }
}

// MARK: Generated accessors for audioFiles
extension Folder {
    @objc(addAudioFilesObject:)
    @NSManaged func addToAudioFiles(_ value: AudioFile)

    @objc(removeAudioFilesObject:)
    @NSManaged func removeFromAudioFiles(_ value: AudioFile)

    @objc(addAudioFiles:)
    @NSManaged func addToAudioFiles(_ values: NSSet)

    @objc(removeAudioFiles:)
    @NSManaged func removeFromAudioFiles(_ values: NSSet)
}

// MARK: Generated accessors for subFolders
extension Folder {
    @objc(addSubFoldersObject:)
    @NSManaged func addToSubFolders(_ value: Folder)

    @objc(removeSubFoldersObject:)
    @NSManaged func removeFromSubFolders(_ value: Folder)

    @objc(addSubFolders:)
    @NSManaged func addToSubFolders(_ values: NSSet)

    @objc(removeSubFolders:)
    @NSManaged func removeFromSubFolders(_ values: NSSet)
}

extension Folder: Identifiable {
    
}