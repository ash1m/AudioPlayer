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
        var folderStructure: [String: (folder: Folder, folderURL: URL, files: [URL])] = [:]
        
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
        
        // Import individual files without smart folder grouping
        // Smart grouping will be done at display time instead
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
                
                // Import the file without folder association
                try await importSingleAudioFile(url: fileURL, folder: nil, context: context)
                results.append(ImportResult(url: fileURL, success: true))
                
            } catch {
                let failureReason = (error as? ImportError)?.errorDescription ?? error.localizedDescription
                results.append(ImportResult(url: fileURL, success: false, error: error, failureReason: failureReason))
            }
        }
        
        // Import files grouped by folder
        for (_, folderData) in folderStructure {
            // Start accessing security-scoped resource for the folder (fresh scope for import phase)
            let folderIsAccessing = folderData.folderURL.startAccessingSecurityScopedResource()
            defer {
                if folderIsAccessing {
                    folderData.folderURL.stopAccessingSecurityScopedResource()
                }
            }
            
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
                    
                    // Import the file and associate with folder, passing the folder URL for artwork detection
                    try await importSingleAudioFile(url: fileURL, folder: folderData.folder, folderURL: folderData.folderURL, context: context)
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
                print("💾 Batch saving all \(results.filter { $0.success }.count) files to context...")
                try context.save()
                print("✅ Context saved successfully")
            } catch {
                print("❌ Failed to save context after folder import: \(error)")
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
    
    private func processDirectory(_ url: URL, folderStructure: inout [String: (folder: Folder, folderURL: URL, files: [URL])], context: NSManagedObjectContext, parentFolder: Folder? = nil) async {
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
                    // Store the folder URL along with the folder entity for later use during import
                    folderStructure[folderPath] = (folder: folder, folderURL: url, files: [])
                }
                // Attempt to detect and save folder artwork if not already set
                if folder.artworkPath == nil {
                    Task {
                        if let relativeArtworkPath = await detectAndSaveFolderArtwork(for: folder, folderURL: url) {
                            await MainActor.run {
                                folder.artworkPath = relativeArtworkPath
                                do {
                                    try context.save()
                                    print("✅ Folder artwork saved for \(folder.name ?? "Folder")")
                                } catch {
                                    print("⚠️ Failed to save context after folder artwork: \(error)")
                                }
                            }
                        }
                    }
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
        let folder = NSEntityDescription.insertNewObject(forEntityName: "Folder", into: context) as! Folder
        folder.id = UUID()
        folder.name = name
        folder.path = path
        folder.parentFolder = parentFolder
        folder.dateAdded = Date()
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
    
    private func importSingleAudioFile(url: URL, folder: Folder? = nil, folderURL: URL? = nil, context: NSManagedObjectContext) async throws {
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
        
        print("\n📝 IMPORT DEBUG:")
        print("   Original filename: \(fileName)")
        print("   Extension: \(fileExtension)")
        print("   Base name: \(baseName)")
        print("   Generated unique filename: \(uniqueFileName)")
        
        // Get the documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileManagerError.documentsDirectoryNotFound
        }
        print("   Documents directory: \(documentsDirectory.path)")
        
        let localURL = documentsDirectory.appendingPathComponent(uniqueFileName)
        print("   Target local URL: \(localURL.path)")
        
        // Copy the file to the documents directory with error handling
        do {
            try FileManager.default.copyItem(at: url, to: localURL)
            print("✅ Successfully copied file to: \(localURL.path)")
            
            // Verify the file actually exists at the expected location
            let fileExists = FileManager.default.fileExists(atPath: localURL.path)
            print("   Verification - File exists at target: \(fileExists)")
            
            if fileExists {
                // Check file size
                if let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    print("   File size: \(fileSize) bytes")
                }
            }
        } catch {
            print("❌ Failed to copy file from \(url.path) to \(localURL.path): \(error)")
            throw error
        }
        
        // Extract basic metadata and artwork
        let metadata = try await extractBasicMetadata(from: localURL)
        // Use provided folder URL if available (for properly-scoped access), otherwise derive from file URL
        let sourceFolderURL = folderURL ?? url.deletingLastPathComponent()
        let artworkPath = await extractAndSaveArtwork(from: localURL, fileName: baseName, folderURL: sourceFolderURL)
        
        // Create the AudioFile entity
        await MainActor.run {
            let audioFile = NSEntityDescription.insertNewObject(forEntityName: "AudioFile", into: context) as! AudioFile
            audioFile.id = UUID()
            // Use filename (without extension) as title, ignore metadata title
            audioFile.title = baseName
            audioFile.artist = metadata.artist
            audioFile.album = metadata.album
            audioFile.genre = metadata.genre
            audioFile.duration = metadata.duration
            // Store ONLY the filename (not the full path) - we'll reconstruct the Documents path at playback time
            // This avoids issues with app container paths changing between launches
            audioFile.filePath = uniqueFileName
            audioFile.fileName = fileName
            audioFile.fileSize = metadata.fileSize
            audioFile.dateAdded = Date()
            audioFile.currentPosition = 0
            audioFile.playCount = 0
            audioFile.artworkPath = artworkPath
            
            print("✅ AudioFile created:")
            print("   Title: \(audioFile.title ?? "nil")")
            print("   Artwork path: \(artworkPath ?? "nil")")
            print("   Associated folder: \(folder?.name ?? "none")")
            
            print("✅ Audio file imported: \(fileName)")
            print("   Stored filename (relative): \(uniqueFileName)")
            print("   Full path (for verification): \(localURL.path)")
            print("   File exists: \(FileManager.default.fileExists(atPath: localURL.path))")
            
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
        // Note: Ignoring title from metadata - using filename instead
        var artist: String?
        var album: String?
        var genre: String?
        
        do {
            let metadata = try await asset.load(.metadata)
            for item in metadata {
                if let key = item.commonKey?.rawValue {
                    let value = try? await item.load(.value)
                    switch key {
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
            title: nil,
            artist: artist,
            album: album,
            genre: genre,
            duration: durationInSeconds.isFinite ? durationInSeconds : 0,
            fileSize: fileSize
        )
    }
    
    private func detectAndSaveFolderArtwork(for folder: Folder, folderURL: URL) async -> String? {
        if let artworkURL = detectFolderArtwork(in: folderURL) {
            do {
                let artworkData = try Data(contentsOf: artworkURL)
                let folderName = folder.name ?? "Folder"
                let fileName = folderName.replacingOccurrences(of: "/", with: "_")
                if let relativeArtworkPath = await saveArtworkToDisk(artworkData, fileName: fileName) {
                    print("🎨 Saved folder artwork for: \(folderName)")
                    return relativeArtworkPath
                }
            } catch {
                print("⚠️ Could not read folder artwork: \(error)")
            }
        }
        return nil
    }
    
    private func detectFolderArtwork(in folderURL: URL, matchingFileName: String? = nil) -> URL? {
        // Start accessing security-scoped resource
        let isAccessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let imageExtensions = ["jpg", "jpeg", "png"]
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            // If matchingFileName provided, search for matching artwork (audiobook_chapter1 -> audiobook.*)
            if let matchingFileName = matchingFileName {
                // Extract the common prefix before any chapter/part indicators
                let commonPrefix = extractCommonFilePrefix(matchingFileName)
                print("🎨 [DETECT FOLDER] Looking for artwork matching prefix: '\(commonPrefix)'")
                
                for item in contents {
                    let fileNameWithoutExt = (item.lastPathComponent as NSString).deletingPathExtension.lowercased()
                    let pathExtension = item.pathExtension.lowercased()
                    
                    // Check if file is an image with matching name (exact or common prefix)
                    if imageExtensions.contains(pathExtension) {
                        print("🎨 [DETECT FOLDER] Found image: \(item.lastPathComponent) (name without ext: '\(fileNameWithoutExt)')")
                        if fileNameWithoutExt == commonPrefix.lowercased() {
                            print("🎨 Found matching artwork: \(item.lastPathComponent) for prefix '\(commonPrefix)'")
                            return item
                        }
                    }
                }
                print("🎨 [DETECT FOLDER] No matching artwork found for prefix '\(commonPrefix)'")
            }
            
            // Fallback: search for common artwork filenames
            print("🎨 [DETECT FOLDER] Searching for common artwork names...")
            let commonArtworkNames = ["cover", "album", "folder", "artwork"]
            for item in contents {
                let fileName = item.lastPathComponent.lowercased()
                let pathExtension = item.pathExtension.lowercased()
                
                // Check if file is an image with common artwork name
                if imageExtensions.contains(pathExtension) {
                    for artworkName in commonArtworkNames {
                        if fileName.hasPrefix(artworkName) {
                            print("🎨 Found common artwork: \(item.lastPathComponent)")
                            return item
                        }
                    }
                }
            }
            print("🎨 [DETECT FOLDER] No common artwork found")
        } catch {
            print("⚠️ Error searching for folder artwork: \(error)")
        }
        
        return nil
    }
    
    private func extractCommonFilePrefix(_ fileName: String) -> String {
        // Extract base name without extension
        let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
        
        // Common patterns: "title - chapter", "title_chapter", "title chapter"
        // Extract the part before chapter indicators
        let patterns = [" - ", " chapter", "_chapter", " ch", "_ch", " - part", "_part"]
        var basePrefix = fileNameWithoutExt
        
        for pattern in patterns {
            if let range = fileNameWithoutExt.range(of: pattern, options: .caseInsensitive) {
                basePrefix = String(fileNameWithoutExt[..<range.lowerBound])
                break
            }
        }
        
        return basePrefix.trimmingCharacters(in: .whitespaces)
    }
    
    private func extractAndSaveArtwork(from url: URL, fileName: String, folderURL: URL? = nil) async -> String? {
        print("🎨 [ARTWORK EXTRACT] Starting for file: \(fileName)")
        let asset = AVURLAsset(url: url)
        
        do {
            let metadata = try await asset.load(.metadata)
            print("🎨 [ARTWORK EXTRACT] Found \(metadata.count) metadata items")
            
            // Look for artwork in metadata
            for item in metadata {
                if let key = item.commonKey?.rawValue, key.contains("artwork") {
                    print("🎨 [ARTWORK EXTRACT] Found artwork key in metadata")
                    if let artworkData = try await item.load(.dataValue) {
                        print("🎨 [ARTWORK EXTRACT] Successfully extracted artwork data (\(artworkData.count) bytes)")
                        // Save artwork to disk - use fileName for consistency
                        let savedPath = await saveArtworkToDisk(artworkData, fileName: fileName)
                        print("🎨 [ARTWORK EXTRACT] Saved embedded artwork to: \(savedPath ?? "failed")")
                        return savedPath
                    }
                }
            }
            print("🎨 [ARTWORK EXTRACT] No embedded artwork found in metadata")
        } catch {
            print("🎨 [ARTWORK EXTRACT] Error: \(error)")
        }
        
        // If no embedded artwork found, try to use folder artwork matching the filename
        if let folderPath = folderURL {
            print("🎨 [ARTWORK EXTRACT] Trying folder artwork in: \(folderPath.lastPathComponent)")
            // Pass fileName for matching (will extract common prefix for grouped files)
            if let folderArtworkURL = detectFolderArtwork(in: folderPath, matchingFileName: fileName) {
                do {
                    let artworkData = try Data(contentsOf: folderArtworkURL)
                    print("🎨 [ARTWORK EXTRACT] Using folder artwork: \(folderArtworkURL.lastPathComponent) (\(artworkData.count) bytes)")
                    let savedPath = await saveArtworkToDisk(artworkData, fileName: fileName)
                    print("🎨 [ARTWORK EXTRACT] Saved folder artwork to: \(savedPath ?? "failed")")
                    return savedPath
                } catch {
                    print("🎨 [ARTWORK EXTRACT] Could not read folder artwork: \(error)")
                }
            } else {
                print("🎨 [ARTWORK EXTRACT] No folder artwork file found")
            }
        } else {
            print("🎨 [ARTWORK EXTRACT] No folder URL provided for fallback")
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
            // Store only the Artwork/filename (relative), not the full absolute path
            // This avoids issues with app container paths changing between launches
            let relativeArtworkPath = "Artwork/\(artworkFileName)"
            return relativeArtworkPath
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
            // Store only the relative path (Artwork/filename), not the full absolute path
            let relativeArtworkPath = "Artwork/\(artworkFileName)"
            audioFile.artworkPath = relativeArtworkPath
            
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
        let folderName = (folder.name ?? "Folder").replacingOccurrences(of: "/", with: "_")
        let artworkFileName = "custom_folder_\(UUID().uuidString)_\(folderName).jpg"
        let artworkURL = artworkDirectory.appendingPathComponent(artworkFileName)
        
        // Save new artwork
        try imageData.write(to: artworkURL)
        
        // Update folder entity
        await MainActor.run {
            // Store only the relative path (Artwork/filename), not the full absolute path
            let relativeArtworkPath = "Artwork/\(artworkFileName)"
            folder.artworkPath = relativeArtworkPath
            
            do {
                try context.save()
                print("✅ Successfully saved custom artwork for folder: \(folder.name ?? "Folder")")
                
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
                print("✅ Successfully removed custom artwork for folder: \(folder.name ?? "Folder")")
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

