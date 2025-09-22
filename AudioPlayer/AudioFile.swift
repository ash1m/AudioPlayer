//
//  AudioFile.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import Foundation
import CoreData

@objc(AudioFile)
class AudioFile: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AudioFile> {
        return NSFetchRequest<AudioFile>(entityName: "AudioFile")
    }

    @NSManaged var id: UUID
    @NSManaged var title: String?
    @NSManaged var artist: String?
    @NSManaged var album: String?
    @NSManaged var genre: String?
    @NSManaged var duration: Double
    @NSManaged var filePath: String
    @NSManaged var fileName: String
    @NSManaged var fileSize: Int64
    @NSManaged var dateAdded: Date
    @NSManaged var lastPlayed: Date?
    @NSManaged var playCount: Int32
    @NSManaged var currentPosition: Double
    @NSManaged var artworkPath: String?
    @NSManaged var folder: Folder?
    @NSManaged var playlistItems: NSSet?
    
    // Computed property for file URL
    var fileURL: URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent(filePath)
    }
    
    // Computed property for artwork URL
    var artworkURL: URL? {
        guard let artworkPath = artworkPath,
              let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent(artworkPath)
    }
    
    // Convenience initializer
    convenience init(context: NSManagedObjectContext, 
                    title: String? = nil,
                    artist: String? = nil,
                    album: String? = nil,
                    genre: String? = nil,
                    duration: Double = 0,
                    filePath: String,
                    fileName: String,
                    fileSize: Int64) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.duration = duration
        self.filePath = filePath
        self.fileName = fileName
        self.fileSize = fileSize
        self.dateAdded = Date()
        self.playCount = 0
        self.currentPosition = 0
    }
}

// MARK: Generated accessors for playlistItems
extension AudioFile {
    @objc(addPlaylistItemsObject:)
    @NSManaged func addToPlaylistItems(_ value: PlaylistItem)

    @objc(removePlaylistItemsObject:)
    @NSManaged func removeFromPlaylistItems(_ value: PlaylistItem)

    @objc(addPlaylistItems:)
    @NSManaged func addToPlaylistItems(_ values: NSSet)

    @objc(removePlaylistItems:)
    @NSManaged func removeFromPlaylistItems(_ values: NSSet)
}

extension AudioFile: Identifiable {
    
}
