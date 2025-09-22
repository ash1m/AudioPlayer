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
    @NSManaged var audioFiles: NSSet?
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
        self.parentFolder = parentFolder
    }
    
    // Computed properties
    var audioFilesArray: [AudioFile] {
        let set = audioFiles as? Set<AudioFile> ?? []
        return Array(set).sorted { $0.title ?? "" < $1.title ?? "" }
    }
    
    var subFoldersArray: [Folder] {
        let set = subFolders as? Set<Folder> ?? []
        return Array(set).sorted { $0.name < $1.name }
    }
    
    // Update file count
    func updateFileCount() {
        let directFileCount = Int32(audioFilesArray.count)
        let subfolderFileCount = subFoldersArray.reduce(0) { total, subfolder in
            return total + subfolder.fileCount
        }
        self.fileCount = directFileCount + subfolderFileCount
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