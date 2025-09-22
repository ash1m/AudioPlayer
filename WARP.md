# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

FireVox is an iOS app built with SwiftUI that allows users to import, organize, and play audio files. The app supports background playback, multiple audio formats, and features a modern tab-based interface.

## Build & Development Commands

### Building the App
```bash
# Build for simulator (Debug)
xcodebuild -project AudioPlayer.xcodeproj -scheme AudioPlayer -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for device (requires provisioning profile)
xcodebuild -project AudioPlayer.xcodeproj -scheme AudioPlayer -configuration Release -destination 'generic/platform=iOS'

# Clean build folder
xcodebuild clean -project AudioPlayer.xcodeproj -scheme AudioPlayer
```

### Testing
```bash
# Run unit tests
xcodebuild test -project AudioPlayer.xcodeproj -scheme AudioPlayer -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project AudioPlayer.xcodeproj -scheme AudioPlayer -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AudioPlayerTests/AudioPlayerTests

# Run UI tests
xcodebuild test -project AudioPlayer.xcodeproj -scheme AudioPlayerUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Opening in Xcode
```bash
# Open project in Xcode
open AudioPlayer.xcodeproj
```

## Architecture & Code Structure

### Core Data Architecture
The app uses Core Data for persistent storage with a single entity:
- **AudioFile**: Stores metadata, file paths, playback position, and artwork references
- **PersistenceController**: Manages Core Data stack with preview support for SwiftUI previews
- Files are stored in Documents directory with unique UUIDs to prevent conflicts

### SwiftUI + MVVM Pattern
The app follows MVVM architecture with ObservableObject services:
- **AudioPlayerService**: Handles audio playback, background audio, and media remote controls
- **AudioFileManager**: Manages file import, metadata extraction, and storage operations  
- **SettingsManager**: Manages app settings and preferences

### Tab-Based Navigation
Three main tabs implemented in `ContentView`:
1. **Library** (`LibraryGridView`): Grid layout showing audio files with artwork
2. **Player** (`AudioPlayerView`): Full-screen audio player with controls
3. **Settings** (`SettingsView`): App configuration and file import

### Audio Import System
Sophisticated import pipeline in `AudioFileManager`:
- Supports both individual files and folder recursion
- Validates audio formats (MP3, M4A, M4B, AAC, WAV, FLAC, AIFF, CAF)
- Extracts metadata using AVFoundation
- Handles artwork extraction and storage
- Prevents duplicate imports
- Security-scoped resource handling for file access

### Background Audio & Media Controls
The app supports background playback through:
- AVAudioSession configuration for `.playback` category
- MPRemoteCommandCenter integration for lock screen/control center
- Background modes enabled in Info.plist
- Position saving/restoration for resuming playback

## Key Implementation Details

### File Management
- Audio files copied to app Documents directory with UUID prefixes
- Artwork stored in separate Artwork subdirectory
- All file operations use security-scoped resources for proper sandboxing

### Memory & Performance
- Uses @FetchRequest for efficient Core Data queries
- AsyncImage for lazy-loaded artwork with fallbacks
- Grid layouts use LazyVGrid for performance with large libraries

### SwiftUI Environment Objects
Key services are injected as environment objects:
```swift
.environmentObject(audioPlayerService)
.environmentObject(audioFileManager)  
.environmentObject(settingsManager)
```

### Testing Infrastructure
- Basic unit test structure in place using Swift Testing framework
- UI tests configured with XCTest
- Preview support with sample data via PersistenceController.preview

## Development Notes

### Audio Format Support
The app validates and supports these formats through `AudioFileManager.validateAudioFormat()`:
- MP3, M4A, M4B, AAC, WAV, FLAC, AIFF, CAF

### Core Data Model Location
- The .xcdatamodeld file exists but uses file system synchronization in the Xcode project
- AudioFile entity defined in `AudioFile.swift` as NSManagedObject subclass

### Playback Features  
- Variable playback speed (0.25x to 3x)
- 15-second skip forward/backward
- Position saving and restoration
- Background playback with remote controls

### Import Error Handling
Comprehensive error handling for import operations:
- Unsupported formats
- Duplicate detection
- File access permissions
- Metadata extraction failures

This codebase prioritizes user experience with comprehensive audio format support, background playback, and robust file management while maintaining clean SwiftUI architecture patterns.

## Accessibility Implementation

The app includes comprehensive accessibility features to support users with various disabilities:

### Core Accessibility Services
- **AccessibilityManager**: Central service managing accessibility settings and announcements
- **DynamicTypeSupport**: View modifiers and utilities for Dynamic Type scaling
- **Visual Accessibility**: High contrast support and reduced motion handling
- **Motor Accessibility**: Proper touch targets (44pt minimum) and spacing

### VoiceOver Support
- All UI elements have proper accessibility labels, hints, and values
- Progress slider supports adjustable actions for VoiceOver users
- Screen change announcements for navigation
- Detailed playback progress announcements

### Accessibility Features
- **Sleep Timer**: Accessible timer with VoiceOver announcements at key intervals
- **Dynamic Text Scaling**: Supports up to .accessibility5 text sizes
- **Adaptive Layouts**: Switch from horizontal to vertical for large text
- **Cognitive Support**: Simplified interface options and consistent UI patterns
- **Motor Support**: Touch target validation and Voice Control compatibility

### Accessibility Testing
Test the app with:
- VoiceOver enabled in iOS Settings
- Dynamic Type set to large accessibility sizes
- Reduce Motion and High Contrast enabled
- Various device orientations and screen sizes
