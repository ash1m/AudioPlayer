//
//  NaturalSort.swift
//  AudioPlayer
//
//  Created by Assistant on 2025/10/07.
//

import Foundation

extension String {
    /// Compare strings naturally, handling embedded numbers correctly
    /// Examples: "01" < "02" < "10", "Chapter 2" < "Chapter 10"
    func naturalCompare(_ other: String) -> ComparisonResult {
        return self.compare(other, options: [.numeric, .caseInsensitive], locale: .current)
    }
    
    /// Check if this string is naturally less than another
    func isNaturallyLessThan(_ other: String) -> Bool {
        return naturalCompare(other) == .orderedAscending
    }
}

extension AudioFile {
    /// Get the filename without extension for natural sorting
    var fileNameWithoutExtension: String {
        return (fileName as NSString).deletingPathExtension
    }
    
    /// Get the best available name for sorting (original filename preferred)
    var displayNameForSorting: String {
        // Use the original filename without extension as the primary sort key
        // This ensures files are ordered by their original names (e.g., "01", "02", "10")
        return fileNameWithoutExtension
    }
}

extension Folder {
    /// Get audio files sorted naturally by filename
    var naturallyOrderedAudioFiles: [AudioFile] {
        let set = audioFiles as? Set<AudioFile> ?? []
        return Array(set).sorted { first, second in
            return first.displayNameForSorting.isNaturallyLessThan(second.displayNameForSorting)
        }
    }
    
    /// Get subfolders sorted naturally by name
    var naturallyOrderedSubFolders: [Folder] {
        let set = subFolders as? Set<Folder> ?? []
        return Array(set).sorted { first, second in
            return first.name.isNaturallyLessThan(second.name)
        }
    }
}