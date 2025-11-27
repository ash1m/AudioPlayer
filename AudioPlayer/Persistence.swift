//
//  Persistence.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/15.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create some sample data for previews
        let sampleAudioFile = NSEntityDescription.insertNewObject(forEntityName: "AudioFile", into: viewContext) as! AudioFile
        sampleAudioFile.id = UUID()
        sampleAudioFile.title = "Sample Song"
        sampleAudioFile.artist = "Sample Artist"
        sampleAudioFile.album = "Sample Album"
        sampleAudioFile.genre = "Rock"
        sampleAudioFile.duration = 240.0
        sampleAudioFile.filePath = "sample.mp3"
        sampleAudioFile.fileName = "sample.mp3"
        sampleAudioFile.fileSize = 5000000
        sampleAudioFile.dateAdded = Date()
        
        // Create sample playlist
        let samplePlaylist = NSEntityDescription.insertNewObject(forEntityName: "Playlist", into: viewContext) as! Playlist
        samplePlaylist.id = UUID()
        samplePlaylist.name = "My Playlist"
        samplePlaylist.dateCreated = Date()
        samplePlaylist.dateModified = Date()
        
        let samplePlaylistItem = NSEntityDescription.insertNewObject(forEntityName: "PlaylistItem", into: viewContext) as! PlaylistItem
        samplePlaylistItem.id = UUID()
        samplePlaylistItem.audioFile = sampleAudioFile
        samplePlaylistItem.playlist = samplePlaylist
        samplePlaylistItem.order = 0
        samplePlaylistItem.dateAdded = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FireVox")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber,
                                                               forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber,
                                                               forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
