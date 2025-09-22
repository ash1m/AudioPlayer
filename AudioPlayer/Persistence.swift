//
//  Persistence.swift
//  AudioPlayer
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
        let sampleAudioFile = AudioFile(
            context: viewContext,
            title: "Sample Song",
            artist: "Sample Artist",
            album: "Sample Album",
            genre: "Rock",
            duration: 240.0,
            filePath: "sample.mp3",
            fileName: "sample.mp3",
            fileSize: 5000000
        )
        
        // Create sample playlist
        let samplePlaylist = Playlist(context: viewContext, name: "My Playlist")
        let samplePlaylistItem = PlaylistItem(context: viewContext, audioFile: sampleAudioFile, playlist: samplePlaylist, order: 0)
        
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
        container = NSPersistentContainer(name: "AudioPlayer")
        
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
