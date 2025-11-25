//
//  AudioFileManager.swift
//  FireVox
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
        
        // Analyze individual files for smart grouping by filename patterns
        let smartGroups = await MainActor.run { analyzeFilesForSmartGrouping(individualFiles, context: context) }
        
        // Import individual files with smart grouping
        for fileURL in individualFiles {
            // Start accessing security-scoped resource for individual files
            let isAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                // Validate file format first
                try validateAudioFormat(url: fileURL)
                
                // Check for duplicates
                try validateNoDuplicate(url: fileURL, existingNames: existingFileNames)
                
                // Determine if this file should go in a smart folder
                let smartFolder = smartGroups.first { group in
                    group.fileURLs.contains(fileURL)
                }?.folder
                
                // Import the file with or without smart folder association
                try await importSingleAudioFile(url: fileURL, folder: smartFolder, context: context)
                results.append(ImportResult(url: fileURL, success: true))
                
            } catch {
                let failureReason = (error as? ImportError)?.errorDescription ?? error.localizedDescription
                results.append(ImportResult(url: fileURL, success: false, error: error, failureReason: failureReason))
            }
        }
        
        // Update smart folder file counts
        for smartGroup in smartGroups {
            await MainActor.run {
                smartGroup.folder.updateFileCount()
            }
        }
        
        // Import files grouped by folder
        for (_, folderData) in folderStructure {
            for fileURL in folderData.files {
                // Start accessing security-scoped resource for folder files
                let isAccessing = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if isAccessing {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                
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
                print("\ud83d\udcbe Batch saving all \(results.filter { $0.success }.count) files to context...")
                try context.save()
                print("\u2705 Context saved successfully")
            } catch {
                print("\u274c Failed to save context after folder import: \(error)")
            }
        }
        
        return results
    }
    
    // MARK: - Smart Grouping Methods
    
    private struct SmartGroup {
        let folder: Folder
        let fileURLs: [URL]
        let pattern: String
    }
    
    @MainActor
    private func analyzeFilesForSmartGrouping(_ files: [URL], context: NSManagedObjectContext) -> [SmartGroup] {
        guard files.count >= 2 else { return [] } // Need at least 2 files to group
        
        // Extract filename patterns
        var patternGroups: [String: [URL]] = [:]
        
        for fileURL in files {
            let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
            
            // Find common patterns in the filename
            let patterns = extractCommonPatterns(from: nameWithoutExtension)
            
            for pattern in patterns {
                if patternGroups[pattern] == nil {
                    patternGroups[pattern] = []
                }
                patternGroups[pattern]?.append(fileURL)
            }
        }
        
        // Sort patterns by specificity (longer patterns first) and file count
        let sortedPatterns = patternGroups
            .filter { $0.value.count >= 3 } // Only consider groups with 3+ files
            .sorted { first, second in
                // First priority: number of files (more files = better group)
                if first.value.count != second.value.count {
                    return first.value.count > second.value.count
                }
                // Second priority: pattern length (longer = more specific)
                return first.key.count > second.key.count
            }
        
        // Create smart groups, prioritizing longer/more specific patterns
        var smartGroups: [SmartGroup] = []
        var usedFiles: Set<URL> = []
        
        for (pattern, groupFiles) in sortedPatterns {
            // Filter out files that are already used in other groups
            let availableFiles = groupFiles.filter { !usedFiles.contains($0) }
            
            if availableFiles.count >= 3 { // Still need at least 3 files after filtering
                let folderName = cleanPatternForFolderName(pattern)
                let folderPath = "smart_group_\(UUID().uuidString)"
                
                let folder = getOrCreateFolder(name: folderName, path: folderPath, parentFolder: nil, context: context)
                
                let smartGroup = SmartGroup(
                    folder: folder,
                    fileURLs: availableFiles,
                    pattern: pattern
                )
                
                smartGroups.append(smartGroup)
                
                // Mark these files as used
                availableFiles.forEach { usedFiles.insert($0) }
            }
        }
        
        return smartGroups
    }
    
    private func extractCommonPatterns(from filename: String) -> [String] {
        var patterns: [String] = []
        let lowercased = filename.lowercased()
        
        // Remove common separators and numbers for pattern matching
        let cleanedName = lowercased
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
        
        // Split into words and look for meaningful patterns
        let words = cleanedName.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 2 } // Filter out short words and numbers
            .filter { word in
                // Filter out common meaningless words and standalone numbers
                let meaninglessWords = ["the", "and", "or", "of", "to", "in", "for", "with", "by", "at", "on", "as", "is", "was", "are", "were", "ch", "cd"]
                return !meaninglessWords.contains(word) && !word.allSatisfy { $0.isNumber }
            }
        
        // Create patterns from consecutive meaningful words
        for i in 0..<words.count {
            // Single word patterns
            if words[i].count >= 4 { // Only consider longer words
                patterns.append(words[i])
            }
            
            // Two word patterns
            if i < words.count - 1 {
                let twoWordPattern = "\(words[i]) \(words[i + 1])"
                patterns.append(twoWordPattern)
            }
            
            // Three word patterns
            if i < words.count - 2 {
                let threeWordPattern = "\(words[i]) \(words[i + 1]) \(words[i + 2])"
                patterns.append(threeWordPattern)
            }
        }
        
        return patterns
    }
    
    private func cleanPatternForFolderName(_ pattern: String) -> String {
        // Capitalize first letter of each word for a nice folder name
        return pattern
            .components(separatedBy: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Folder Processing Methods
    
    private func processDirectory(_ url: URL, folderStructure: inout [String: (folder: Folder, files: [URL])], context: NSManagedObjectContext, parentFolder: Folder? = nil) async {
        // Start accessing security-scoped resource for this directory
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let folderName = url.lastPathComponent
            let folderPath = url.path
            
            await MainActor.run {
                // Get or create folder entity
                let folder = getOrCreateFolder(name: folderName, path: folderPath, parentFolder: parentFolder, context: context)
                if folderStructure[folderPath] == nil {
                    folderStructure[folderPath] = (folder: folder, files: [])
                }
            }
            
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            for item in contents {
                // Start accessing security-scoped resource for each child item
                let isChildAccessing = item.startAccessingSecurityScopedResource()
                defer {
                    if isChildAccessing {
                        item.stopAccessingSecurityScopedResource()
                    }
                }
                
                var isItemDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isItemDirectory) else {
                    continue
                }
                
                if isItemDirectory.boolValue {
                    // Recursively process subdirectory (security scope will be handled in recursive call)
                    // Pass parentFolder as nil so inside the recursive call the folder is resolved again inside MainActor
                    await processDirectory(item, folderStructure: &folderStructure, context: context, parentFolder: nil)
                } else {
                    // Add audio file to this folder inside Main Actor context to keep concurrency safe
                    if isAudioFile(item) {
                        await MainActor.run {
                            folderStructure[folderPath]?.files.append(item)
                        }
                    }
                }
            }
        } catch {
            print("Error processing directory \(url.path): \(error)")
        }
    }
    
    @MainActor
    private func getOrCreateFolder(name: String, path: String, parentFolder: Folder?, context: NSManagedObjectContext) -> Folder {
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
                // Start accessing security-scoped resource for each child item
                let isChildAccessing = item.startAccessingSecurityScopedResource()
                defer {
                    if isChildAccessing {
                        item.stopAccessingSecurityScopedResource()
                    }
                }
                
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
        // Since we store UUID-prefixed file paths (filePath), each import automatically
        // gets a unique storage path. We don't need filename-based duplicate detection
        // because the UUID ensures uniqueness regardless of the original filename.
        // If needed in the future, we could check file content hash instead.
    }
    
    private func getExistingFileNames(context: NSManagedObjectContext) async -> Set<String> {
        return await MainActor.run {
            let request = AudioFile.fetchRequest()
            request.propertiesToFetch = ["filePath"]
            
            do {
                let existingFiles = try context.fetch(request)
                return Set(existingFiles.compactMap { $0.filePath })
            } catch {
                print("Error fetching existing file paths: \(error)")
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
            
            // Don't save here - let the caller batch save all files at once
            print("✅ Created AudioFile entity: \(fileName)")
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
    
    // MARK: - Artwork Diagnostics
    
    func debugArtworkStatus(for audioFile: AudioFile) {
        print("🎨 Debugging artwork for: \(audioFile.title ?? "Unknown")")
        print("   artworkPath: \(audioFile.artworkPath ?? "nil")")
        
        if let artworkURL = audioFile.artworkURL {
            print("   artworkURL: \(artworkURL.path)")
            let exists = FileManager.default.fileExists(atPath: artworkURL.path)
            print("   File exists: \(exists)")
            
            if exists {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: artworkURL.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        print("   File size: \(fileSize) bytes")
                    }
                } catch {
                    print("   Error getting file attributes: \(error)")
                }
            }
        } else {
            print("   artworkURL: nil")
        }
    }
    
    func listArtworkDirectory() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("🎨 Documents directory not found")
            return
        }
        
        let artworkDirectory = documentsDirectory.appendingPathComponent("Artwork")
        print("🎨 Artwork directory: \(artworkDirectory.path)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: artworkDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [])
            print("🎨 Found \(files.count) artwork files:")
            
            for file in files {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("   - \(file.lastPathComponent) (\(fileSize) bytes)")
                } catch {
                    print("   - \(file.lastPathComponent) (size unknown)")
                }
            }
        } catch {
            print("🎨 Error listing artwork directory: \(error)")
        }
    }
    
    func verifyAllArtwork(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<AudioFile> = AudioFile.fetchRequest()
        
        do {
            let audioFiles = try context.fetch(fetchRequest)
            print("🎨 Verifying artwork for \(audioFiles.count) audio files:")
            
            var hasArtworkPath = 0
            var artworkFileExists = 0
            var artworkFileMissing = 0
            
            for audioFile in audioFiles {
                if audioFile.artworkPath != nil {
                    hasArtworkPath += 1
                    
                    if let artworkURL = audioFile.artworkURL, FileManager.default.fileExists(atPath: artworkURL.path) {
                        artworkFileExists += 1
                    } else {
                        artworkFileMissing += 1
                        print("   ❌ Missing artwork for: \(audioFile.title ?? "Unknown")")
                    }
                }
            }
            
            print("🎨 Summary:")
            print("   - Files with artworkPath: \(hasArtworkPath)")
            print("   - Artwork files exist: \(artworkFileExists)")
            print("   - Artwork files missing: \(artworkFileMissing)")
            
        } catch {
            print("🎨 Error fetching audio files: \(error)")
        }
    }
    
    // MARK: - Custom Artwork Management
    
    func saveCustomArtwork(for audioFile: AudioFile, imageData: Data, context: NSManagedObjectContext, audioPlayerService: AudioPlayerService? = nil) async throws {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileManagerError.documentsDirectoryNotFound
        }
        
        // Create artwork folder if it doesn't exist
        let artworkDirectory = documentsDirectory.appendingPathComponent("Artwork")
        if !FileManager.default.fileExists(atPath: artworkDirectory.path) {
            try FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
        }
        
        // Delete old custom artwork if it exists
        await MainActor.run {
            if let oldArtworkURL = audioFile.artworkURL,
               FileManager.default.fileExists(atPath: oldArtworkURL.path) {
                try? FileManager.default.removeItem(at: oldArtworkURL)
            }
        }
        
        // Create unique filename for new custom artwork
        let fileName = audioFile.originalFileNameWithoutExtension
        let artworkFileName = "custom_\(UUID().uuidString)_\(fileName).jpg"
        let artworkURL = artworkDirectory.appendingPathComponent(artworkFileName)
        
        // Save new artwork
        try imageData.write(to: artworkURL)
        
        // Update audio file entity
        await MainActor.run {
            audioFile.artworkPath = "Artwork/\(artworkFileName)"
            
            do {
                try context.save()
                print("✅ Successfully saved custom artwork for: \(audioFile.title ?? "Unknown")")
                
                // Notify AudioPlayerService if this is the currently playing file
                audioPlayerService?.artworkDidUpdate(for: audioFile)
                
            } catch {
                print("❌ Failed to save context after updating artwork: \(error)")
                // Clean up the file if Core Data save failed
                try? FileManager.default.removeItem(at: artworkURL)
            }
        }
    }
    
    func removeCustomArtwork(for audioFile: AudioFile, context: NSManagedObjectContext) async {
        await MainActor.run {
            // Delete the artwork file
            if let artworkURL = audioFile.artworkURL,
               FileManager.default.fileExists(atPath: artworkURL.path) {
                try? FileManager.default.removeItem(at: artworkURL)
            }
            
            // Clear the artwork path in Core Data
            audioFile.artworkPath = nil
            
            do {
                try context.save()
                print("✅ Successfully removed custom artwork for: \(audioFile.title ?? "Unknown")")
            } catch {
                print("❌ Failed to save context after removing artwork: \(error)")
            }
        }
    }
    
    func hasCustomArtwork(for audioFile: AudioFile) -> Bool {
        guard let artworkPath = audioFile.artworkPath else { return false }
        return artworkPath.contains("custom_")
    }
    
    // MARK: - Folder Artwork Management
    
    func saveCustomArtwork(for folder: Folder, imageData: Data, context: NSManagedObjectContext, audioPlayerService: AudioPlayerService? = nil) async throws {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileManagerError.documentsDirectoryNotFound
        }
        
        // Create artwork folder if it doesn't exist
        let artworkDirectory = documentsDirectory.appendingPathComponent("Artwork")
        if !FileManager.default.fileExists(atPath: artworkDirectory.path) {
            try FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
        }
        
        // Delete old custom artwork if it exists
        await MainActor.run {
            if let oldArtworkURL = folder.artworkURL,
               FileManager.default.fileExists(atPath: oldArtworkURL.path) {
                try? FileManager.default.removeItem(at: oldArtworkURL)
            }
        }
        
        // Create unique filename for new custom folder artwork
        let folderName = folder.name.replacingOccurrences(of: "/", with: "_")
        let artworkFileName = "custom_folder_\(UUID().uuidString)_\(folderName).jpg"
        let artworkURL = artworkDirectory.appendingPathComponent(artworkFileName)
        
        // Save new artwork
        try imageData.write(to: artworkURL)
        
        // Update folder entity
        await MainActor.run {
            folder.artworkPath = "Artwork/\(artworkFileName)"
            
            do {
                try context.save()
                print("✅ Successfully saved custom artwork for folder: \(folder.name)")
                
                // Notify AudioPlayerService if we're playing from this folder
                if let currentFile = audioPlayerService?.currentAudioFile,
                   currentFile.folder == folder {
                    audioPlayerService?.artworkDidUpdate(for: currentFile)
                }
                
            } catch {
                print("❌ Failed to save context after updating folder artwork: \(error)")
                // Clean up the file if Core Data save failed
                try? FileManager.default.removeItem(at: artworkURL)
            }
        }
    }
    
    func removeCustomArtwork(for folder: Folder, context: NSManagedObjectContext) async {
        await MainActor.run {
            // Delete the artwork file
            if let artworkURL = folder.artworkURL,
               FileManager.default.fileExists(atPath: artworkURL.path) {
                try? FileManager.default.removeItem(at: artworkURL)
            }
            
            // Clear the artwork path in Core Data
            folder.artworkPath = nil
            
            do {
                try context.save()
                print("✅ Successfully removed custom artwork for folder: \(folder.name)")
            } catch {
                print("❌ Failed to save context after removing folder artwork: \(error)")
            }
        }
    }
    
    func hasCustomArtwork(for folder: Folder) -> Bool {
        guard let artworkPath = folder.artworkPath else { return false }
        return artworkPath.contains("custom_folder_")
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

