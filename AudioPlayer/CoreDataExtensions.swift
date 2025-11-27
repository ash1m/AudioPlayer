import Foundation
import CoreData

// MARK: - AudioFile Extensions
extension AudioFile {
    var fileURL: URL? {
        guard let filePath = filePath else { return nil }
        
        // Check if filePath is already an absolute path (contains /var/mobile or /Users)
        if filePath.contains("/var/mobile") || filePath.contains("/Users") {
            // Old format: absolute path - use it as-is for backwards compatibility
            return URL(fileURLWithPath: filePath)
        }
        
        // New format: just the filename - reconstruct the full path in Documents
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsDirectory.appendingPathComponent(filePath)
        }
        
        return nil
    }
    
    var artworkURL: URL? {
        guard let artworkPath = artworkPath else { return nil }
        
        // Check if artworkPath is already an absolute path (contains /var/mobile or /Users)
        if artworkPath.contains("/var/mobile") || artworkPath.contains("/Users") {
            // Old format: absolute path - use it as-is for backwards compatibility
            return URL(fileURLWithPath: artworkPath)
        }
        
        // New format: relative path ("Artwork/filename") - reconstruct the full path
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsDirectory.appendingPathComponent(artworkPath)
        }
        
        return nil
    }
    
    var safeID: UUID {
        id ?? UUID()
    }
    
    var safeTitle: String {
        title ?? (fileName ?? "Unknown")
    }
    
    var safeArtist: String {
        artist ?? "Unknown Artist"
    }
    
    var safeAlbum: String {
        album ?? "Unknown Album"
    }
    
    var originalFileNameWithoutExtension: String {
        guard let fileName = fileName else { return "Unknown" }
        return (fileName as NSString).deletingPathExtension
    }
}

// MARK: - Folder Extensions
extension Folder {
    var safeID: UUID {
        return id ?? UUID()
    }
    
    var safeName: String {
        return name ?? "Unnamed Folder"
    }
    
    var audioFilesArray: [AudioFile] {
        let set = audioFiles as? Set<AudioFile> ?? []
        return Array(set).sorted { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
    }
    
    var subFoldersArray: [Folder] {
        let set = subFolders as? Set<Folder> ?? []
        return Array(set).sorted { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
    }
    
    func updateFileCount() {
        let fetchRequest: NSFetchRequest<AudioFile> = AudioFile.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "folder == %@", self)
        
        if let managedObjectContext = managedObjectContext {
            do {
                let count = try managedObjectContext.count(for: fetchRequest)
                fileCount = Int32(count)
            } catch {
                print("Error updating file count: \(error)")
            }
        }
    }
    
    var artworkURL: URL? {
        guard let artworkPath = artworkPath else { return nil }
        return URL(fileURLWithPath: artworkPath)
    }
    
    var totalDuration: TimeInterval {
        return audioFilesArray.reduce(0) { $0 + $1.duration }
    }
    
    func getCurrentFolderPosition() -> TimeInterval {
        return lastPlayedPosition ?? 0
    }
    
    func savePlaybackState(position: TimeInterval) {
        lastPlayedPosition = position
        lastPlayedDate = Date()
    }
    
    func hasPlaybackState() -> Bool {
        return lastPlayedPosition ?? 0 > 0
    }
    
    func getResumeAudioFile() -> AudioFile? {
        return lastPlayedAudioFile
    }
    
    func getResumePosition() -> TimeInterval {
        return lastPlayedPosition ?? 0
    }
}

// MARK: - Playlist Extensions
extension Playlist {
    var safeID: UUID {
        return id ?? UUID()
    }
    
    var safeName: String {
        return name ?? "Unnamed Playlist"
    }
    
    var orderedItems: [PlaylistItem] {
        let set = playlistItems as? Set<PlaylistItem> ?? []
        return Array(set).sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
}

// MARK: - PlaylistItem Extensions
extension PlaylistItem {
    var safeID: UUID {
        id ?? UUID()
    }
}
