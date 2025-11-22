//
//  PlaylistManager.swift
//  FireVox
//
//  Created by Ashim S on 2025/09/20.
//

import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
class PlaylistManager: ObservableObject {
    @Published var currentPlaylist: Playlist?
    @Published var isLoading = false
    
    private var viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        loadOrCreateDefaultPlaylist()
    }
    
    // MARK: - Playlist Management
    
    private func loadOrCreateDefaultPlaylist() {
        let request: NSFetchRequest<Playlist> = Playlist.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Playlist.dateCreated, ascending: true)]
        request.fetchLimit = 1
        
        do {
            let playlists = try viewContext.fetch(request)
            if let existingPlaylist = playlists.first {
                currentPlaylist = existingPlaylist
            } else {
                // Create default playlist
                let newPlaylist = Playlist(context: viewContext, name: "My Playlist")
                try viewContext.save()
                currentPlaylist = newPlaylist
            }
        } catch {
            print("Error loading or creating playlist: \(error)")
        }
    }
    
    // MARK: - Adding Files to Playlist
    
    func addAudioFiles(_ audioFiles: [AudioFile]) {
        guard let playlist = currentPlaylist else { return }
        
        isLoading = true
        
        let existingItems = playlist.orderedItems
        var nextOrder = Int32(existingItems.count)
        
        for audioFile in audioFiles {
            // Check if file is already in playlist
            let isAlreadyInPlaylist = existingItems.contains { item in
                item.audioFile?.id == audioFile.id
            }
            
            if !isAlreadyInPlaylist {
                _ = PlaylistItem(
                    context: viewContext,
                    audioFile: audioFile,
                    playlist: playlist,
                    order: nextOrder
                )
                nextOrder += 1
            }
        }
        
        playlist.dateModified = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error adding files to playlist: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Removing Files from Playlist
    
    func removePlaylistItem(_ playlistItem: PlaylistItem) {
        guard let playlist = currentPlaylist else { return }
        
        // Remove the item from Core Data
        viewContext.delete(playlistItem)
        
        // Save the context to ensure the deletion is persisted
        playlist.dateModified = Date()
        
        do {
            try viewContext.save()
            
            // After successful save, reorder the remaining items
            let remainingItems = playlist.orderedItems.sorted { $0.order < $1.order }
            for (index, item) in remainingItems.enumerated() {
                item.order = Int32(index)
            }
            
            // Save again after reordering
            try viewContext.save()
        } catch {
            print("Error removing playlist item: \(error)")
        }
    }
    
    // MARK: - Reordering
    
    func movePlaylistItem(from source: IndexSet, to destination: Int) {
        guard let playlist = currentPlaylist else { return }
        
        var items = playlist.orderedItems
        items.move(fromOffsets: source, toOffset: destination)
        
        // Update order for all items
        for (index, item) in items.enumerated() {
            item.order = Int32(index)
        }
        
        playlist.dateModified = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error reordering playlist items: \(error)")
        }
    }
    
    // MARK: - Playlist Utilities
    
    func clearPlaylist() {
        guard let playlist = currentPlaylist else { return }
        
        for item in playlist.orderedItems {
            viewContext.delete(item)
        }
        
        playlist.dateModified = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("Error clearing playlist: \(error)")
        }
    }
    
    func getPlaylistDuration() -> TimeInterval {
        guard let playlist = currentPlaylist else { return 0 }
        
        return playlist.orderedItems.reduce(0) { total, item in
            total + (item.audioFile?.duration ?? 0)
        }
    }
    
    func getPlaylistCount() -> Int {
        return currentPlaylist?.orderedItems.count ?? 0
    }
    
    // MARK: - Queue Operations
    
    func findItemIndex(for audioFile: AudioFile) -> Int? {
        guard let playlist = currentPlaylist else { return nil }
        
        return playlist.orderedItems.firstIndex { playlistItem in
            playlistItem.audioFile?.id == audioFile.id
        }
    }
    
    func getNextItem(after currentIndex: Int) -> PlaylistItem? {
        guard let playlist = currentPlaylist else { return nil }
        let items = playlist.orderedItems
        
        let nextIndex = currentIndex + 1
        guard nextIndex < items.count else { return nil }
        
        return items[nextIndex]
    }
    
    func getPreviousItem(before currentIndex: Int) -> PlaylistItem? {
        guard let playlist = currentPlaylist else { return nil }
        let items = playlist.orderedItems
        
        let previousIndex = currentIndex - 1
        guard previousIndex >= 0 else { return nil }
        
        return items[previousIndex]
    }
    
    func getItem(at index: Int) -> PlaylistItem? {
        guard let playlist = currentPlaylist else { return nil }
        let items = playlist.orderedItems
        
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }
    
    // MARK: - Cascade Delete Support
    
    func removePlaylistItemsForAudioFile(_ audioFile: AudioFile) {
        guard let playlist = currentPlaylist else { return }
        
        let itemsToRemove = playlist.orderedItems.filter { playlistItem in
            playlistItem.audioFile?.id == audioFile.id
        }
        
        if !itemsToRemove.isEmpty {
            // Delete all matching items
            for item in itemsToRemove {
                viewContext.delete(item)
            }
            
            playlist.dateModified = Date()
            
            do {
                try viewContext.save()
                
                // After successful save, reorder the remaining items
                let remainingItems = playlist.orderedItems.sorted { $0.order < $1.order }
                for (index, item) in remainingItems.enumerated() {
                    item.order = Int32(index)
                }
                
                // Save again after reordering
                try viewContext.save()
            } catch {
                print("Error removing playlist items for audio file: \(error)")
            }
        }
    }
    
    // Static method for use in other contexts without access to current playlist
    static func removeAllPlaylistItemsForAudioFile(_ audioFile: AudioFile, context: NSManagedObjectContext) {
        let request: NSFetchRequest<PlaylistItem> = PlaylistItem.fetchRequest()
        request.predicate = NSPredicate(format: "audioFile == %@", audioFile)
        
        do {
            let items = try context.fetch(request)
            for item in items {
                context.delete(item)
            }
            try context.save()
        } catch {
            print("Error removing all playlist items for audio file: \(error)")
        }
    }
}
