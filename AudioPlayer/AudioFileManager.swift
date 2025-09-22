//
//  AudioFileManager.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/09/15.
//

import Foundation
import CoreData
import AVFoundation
import Combine

class AudioFileManager: ObservableObject {
    
    struct ImportResult {
        let url: URL
        let fileName: String
        let success: Bool
        let error: Error?
        let failureReason: String?
        
        init(url: URL, success: Bool, error: Error? = nil, failureReason: String? = nil) {
            self.url = url
            self.fileName = url.lastPathComponent
            self.success = success
            self.error = error
            self.failureReason = failureReason
        }
    }
    
    enum ImportError: Error, LocalizedError {
        case unsupportedFormat(String)
        case duplicateFile(String)
        case invalidFile(String)
        case folderProcessingError(String)
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let format):
                return "Unsupported audio format: \(format)"
            case .duplicateFile(let name):
                return "File with similar name already exists: \(name)"
            case .invalidFile(let reason):
                return "Invalid file: \(reason)"
            case .folderProcessingError(let reason):
                return "Folder processing error: \(reason)"
            }
        }
    }
    
    // MARK: - File Import
    
    func importAudioFiles(urls: [URL], context: NSManagedObjectContext) async -> [ImportResult] {
        var results: [ImportResult] = []
        var individualFiles: [URL] = []
        var folderStructure: [String: (folder: Folder, files: [URL])] = [:]
        
        // Get existing file names for duplicate detection
        let existingFileNames = await getExistingFileNames(context: context)
        
        // First, categorize URLs into individual files vs folders
        for url in urls {
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }
            
            if isDirectory.boolValue {
                // It's a folder - process with folder structure
                await processDirectory(url, folderStructure: &folderStructure, context: context)
            } else {
                // It's an individual file - add to individual files list
                if isAudioFile(url) {
                    individualFiles.append(url)
                }
            }
        }
        
        // Import individual files to root (no folder association)
        for fileURL in individualFiles {
            do {
                // Validate file format first
                try validateAudioFormat(url: fileURL)
                
                // Check for duplicates
                try validateNoDuplicate(url: fileURL, existingNames: existingFileNames)
                
                // Import the file without folder association
                try await importSingleAudioFile(url: fileURL, folder: nil, context: context)
                results.append(ImportResult(url: fileURL, success: true))
                
            } catch {
                let failureReason = (error as? ImportError)?.errorDescription ?? error.localizedDescription
                results.append(ImportResult(url: fileURL, success: false, error: error, failureReason: failureReason))
            }
        }
        
        // Import files grouped by folder
        for (folderPath, folderData) in folderStructure {
            for fileURL in folderData.files {
                do {
                    // Validate file format first
                    try validateAudioFormat(url: fileURL)
                    
                    // Check for duplicates
                    try validateNoDuplicate(url: fileURL, existingNames: existingFileNames)
                    
                    // Import the file and associate with folder
                    try await importSingleAudioFile(url: fileURL, folder: folderData.folder, context: context)
                    results.append(ImportResult(url: fileURL, success: true))
                    
                } catch {
                    let failureReason = (error as? ImportError)?.errorDescription ?? error.localizedDescription
                    results.append(ImportResult(url: fileURL, success: false, error: error, failureReason: failureReason))
                }
            }
            
            // Update folder file count
            await MainActor.run {
                folderData.folder.updateFileCount()
            }
        }
        
        // Save context after all imports
        await MainActor.run {
            do {
                try context.save()
            } catch {
                print("Failed to save context after folder import: \(error)")
            }
        }
        
        return results
    }
    
    // MARK: - Folder Processing Methods
    
    private func processDirectory(_ url: URL, folderStructure: inout [String: (folder: Folder, files: [URL])], context: NSManagedObjectContext, parentFolder: Folder? = nil) async {
        do {
            let folderName = url.lastPathComponent
            let folderPath = url.path
            
            // Create or get folder entity
            let folder = await getOrCreateFolder(name: folderName, path: folderPath, parentFolder: parentFolder, context: context)
            
            if folderStructure[folderPath] == nil {
                folderStructure[folderPath] = (folder: folder, files: [])
            }
            
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            for item in contents {
                var isItemDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isItemDirectory) else {
                    continue
                }
                
                if isItemDirectory.boolValue {
                    // Recursively process subdirectory
                    await processDirectory(item, folderStructure: &folderStructure, context: context, parentFolder: folder)
                } else {
                    // Add audio file to this folder
                    if isAudioFile(item) {
                        folderStructure[folderPath]?.files.append(item)
                    }
                }
            }
        } catch {
            print("Error processing directory \(url.path): \(error)")
        }
    }
    
    private func getOrCreateFolder(name: String, path: String, parentFolder: Folder?, context: NSManagedObjectContext) async -> Folder {
        return await MainActor.run {
            // Check if folder already exists
            let request = Folder.fetchRequest()
            request.predicate = NSPredicate(format: "path == %@", path)
            
            do {
                let existingFolders = try context.fetch(request)
                if let existingFolder = existingFolders.first {
                    return existingFolder
                }
            } catch {
                print("Error fetching existing folder: \(error)")
            }
            
            // Create new folder
            let folder = Folder(context: context, name: name, path: path, parentFolder: parentFolder)
            return folder
        }
    }
    
    private func isAudioFile(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        let supportedFormats = ["mp3", "m4a", "m4b", "aac", "wav", "flac", "aiff", "caf"]
        return supportedFormats.contains(pathExtension)
    }
    
    // MARK: - Validation Methods
    
    private func extractFilesFromURL(_ url: URL) async -> [URL] {
        // Start accessing security-scoped resource
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }
        
        if !isDirectory.boolValue {
            // It's a file, return as-is
            return [url]
        }
        
        // It's a directory, recursively find audio files
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            var audioFiles: [URL] = []
            for item in contents {
                let subFiles = await extractFilesFromURL(item)
                audioFiles.append(contentsOf: subFiles)
            }
            return audioFiles
        } catch {
            print("Error reading directory \(url.path): \(error)")
            return []
        }
    }
    
    private func validateAudioFormat(url: URL) throws {
        let pathExtension = url.pathExtension.lowercased()
        let supportedFormats = ["mp3", "m4a", "m4b", "aac", "wav", "flac", "aiff", "caf"]
        
        guard supportedFormats.contains(pathExtension) else {
            throw ImportError.unsupportedFormat(pathExtension.isEmpty ? "No extension" : "\(pathExtension.uppercased())")
        }
    }
    
    private func validateNoDuplicate(url: URL, existingNames: Set<String>) throws {
        let fileName = url.lastPathComponent
        let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
        
        // Check exact name match
        if existingNames.contains(fileName) {
            throw ImportError.duplicateFile(fileName)
        }
        
        // Check for similar names (same name but different extension)
        for existingName in existingNames {
            let existingNameWithoutExt = (existingName as NSString).deletingPathExtension
            if existingNameWithoutExt.lowercased() == nameWithoutExtension.lowercased() {
                throw ImportError.duplicateFile("Similar to existing: \(existingName)")
            }
        }
    }
    
    private func getExistingFileNames(context: NSManagedObjectContext) async -> Set<String> {
        return await MainActor.run {
            let request = AudioFile.fetchRequest()
            request.propertiesToFetch = ["fileName"]
            
            do {
                let existingFiles = try context.fetch(request)
                return Set(existingFiles.compactMap { $0.fileName })
            } catch {
                print("Error fetching existing file names: \(error)")
                return Set<String>()
            }
        }
    }
    
    private func importSingleAudioFile(url: URL, folder: Folder? = nil, context: NSManagedObjectContext) async throws {
        // Start accessing the security-scoped resource
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Create a unique filename to avoid conflicts
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension
        let baseName = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
        let uniqueFileName = "\(UUID().uuidString)_\(baseName).\(fileExtension)"
        
        // Get the documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileManagerError.documentsDirectoryNotFound
        }
        let localURL = documentsDirectory.appendingPathComponent(uniqueFileName)
        
        // Copy the file to the documents directory with error handling
        do {
            try FileManager.default.copyItem(at: url, to: localURL)
            print("Successfully copied file to: \(localURL.path)")
        } catch {
            print("Failed to copy file from \(url.path) to \(localURL.path): \(error)")
            throw error
        }
        
        // Extract basic metadata and artwork
        let metadata = try await extractBasicMetadata(from: localURL)
        let artworkPath = await extractAndSaveArtwork(from: localURL, fileName: baseName)
        
        // Create the AudioFile entity
        await MainActor.run {
            let audioFile = AudioFile(
                context: context,
                title: metadata.title ?? baseName,
                artist: metadata.artist,
                album: metadata.album,
                genre: metadata.genre,
                duration: metadata.duration,
                filePath: uniqueFileName,
                fileName: fileName,
                fileSize: metadata.fileSize
            )
            audioFile.artworkPath = artworkPath
            
            // Associate with folder if provided
            if let folder = folder {
                audioFile.folder = folder
            }
            
            do {
                try context.save()
            } catch {
                // If saving fails, remove the copied file
                try? FileManager.default.removeItem(at: localURL)
                print("Failed to save audio file: \(error)")
            }
        }
    }
    
    // MARK: - Metadata Extraction (Simplified)
    
    private func extractBasicMetadata(from url: URL) async throws -> AudioMetadata {
        let asset = AVURLAsset(url: url)
        
        // Get duration
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            duration = CMTime.zero
        }
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        // Get file size
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            fileSize = 0
        }
        
        // Basic metadata extraction
        var title: String?
        var artist: String?
        var album: String?
        var genre: String?
        
        do {
            let metadata = try await asset.load(.metadata)
            for item in metadata {
                if let key = item.commonKey?.rawValue {
                    let value = try? await item.load(.value)
                    switch key {
                    case "title":
                        title = value as? String
                    case "artist":
                        artist = value as? String
                    case "albumName":
                        album = value as? String
                    case "subject":
                        genre = value as? String
                    default:
                        break
                    }
                }
            }
        } catch {
            print("Could not extract metadata: \(error)")
        }
        
        return AudioMetadata(
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            duration: durationInSeconds.isFinite ? durationInSeconds : 0,
            fileSize: fileSize
        )
    }
    
    private func extractAndSaveArtwork(from url: URL, fileName: String) async -> String? {
        let asset = AVURLAsset(url: url)
        
        do {
            let metadata = try await asset.load(.metadata)
            
            // Look for artwork in metadata
            for item in metadata {
                if let key = item.commonKey?.rawValue, key.contains("artwork") {
                    if let artworkData = try await item.load(.dataValue) {
                        // Save artwork to disk
                        return await saveArtworkToDisk(artworkData, fileName: fileName)
                    }
                }
            }
        } catch {
            print("Could not extract artwork: \(error)")
        }
        
        return nil
    }
    
    private func saveArtworkToDisk(_ data: Data, fileName: String) async -> String? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Create artwork folder if it doesn't exist
        let artworkDirectory = documentsDirectory.appendingPathComponent("Artwork")
        if !FileManager.default.fileExists(atPath: artworkDirectory.path) {
            try? FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
        }
        
        // Create unique filename for artwork
        let artworkFileName = "\(UUID().uuidString)_\(fileName).jpg"
        let artworkURL = artworkDirectory.appendingPathComponent(artworkFileName)
        
        do {
            try data.write(to: artworkURL)
            return "Artwork/\(artworkFileName)"
        } catch {
            print("Failed to save artwork: \(error)")
            return nil
        }
    }
    
    // MARK: - File Management
    
    func deleteAudioFile(_ audioFile: AudioFile) throws {
        // Delete the audio file
        if let fileURL = audioFile.fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        // Delete the artwork file if it exists
        if let artworkURL = audioFile.artworkURL, FileManager.default.fileExists(atPath: artworkURL.path) {
            try? FileManager.default.removeItem(at: artworkURL)
        }
    }
    
    func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    func fileExists(for audioFile: AudioFile) -> Bool {
        guard let fileURL = audioFile.fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}

// MARK: - Supporting Types

struct AudioMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let genre: String?
    let duration: Double
    let fileSize: Int64
}

enum FileManagerError: Error {
    case documentsDirectoryNotFound
}