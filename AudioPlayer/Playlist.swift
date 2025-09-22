//
//  Playlist.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/20.
//

import Foundation
import CoreData

@objc(Playlist)
class Playlist: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Playlist> {
        return NSFetchRequest<Playlist>(entityName: "Playlist")
    }

    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var dateCreated: Date
    @NSManaged var dateModified: Date
    @NSManaged var playlistItems: NSSet?
    
    // Computed property for ordered playlist items
    var orderedItems: [PlaylistItem] {
        guard let items = playlistItems?.allObjects as? [PlaylistItem] else { return [] }
        return items.sorted { $0.order < $1.order }
    }
    
    // Convenience initializer
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.dateCreated = Date()
        self.dateModified = Date()
    }
}

// MARK: Generated accessors for playlistItems
extension Playlist {
    @objc(addPlaylistItemsObject:)
    @NSManaged func addToPlaylistItems(_ value: PlaylistItem)

    @objc(removePlaylistItemsObject:)
    @NSManaged func removeFromPlaylistItems(_ value: PlaylistItem)

    @objc(addPlaylistItems:)
    @NSManaged func addToPlaylistItems(_ values: NSSet)

    @objc(removePlaylistItems:)
    @NSManaged func removeFromPlaylistItems(_ values: NSSet)
}

extension Playlist: Identifiable {
    
}

@objc(PlaylistItem)
class PlaylistItem: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PlaylistItem> {
        return NSFetchRequest<PlaylistItem>(entityName: "PlaylistItem")
    }

    @NSManaged var id: UUID
    @NSManaged var order: Int32
    @NSManaged var dateAdded: Date
    @NSManaged var playlist: Playlist?
    @NSManaged var audioFile: AudioFile?
    
    // Convenience initializer
    convenience init(context: NSManagedObjectContext, audioFile: AudioFile, playlist: Playlist, order: Int32) {
        self.init(context: context)
        self.id = UUID()
        self.audioFile = audioFile
        self.playlist = playlist
        self.order = order
        self.dateAdded = Date()
    }
}

extension PlaylistItem: Identifiable {
    
}