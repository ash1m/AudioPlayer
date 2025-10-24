# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

AudioPlayer is an iOS app built with **pure SwiftUI** that allows users to import, organize, and play audio files. The app supports background playback, multiple audio formats, and features a modern tab-based interface with comprehensive accessibility support.

## Build & Development Commands

### Building the App
```bash
# Build for simulator (Debug) - Use available simulators
xcodebuild -project AudioPlayer.xcodeproj -scheme AudioPlayer -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Alternative: Build for any iOS simulator
xcodebuild -project AudioPlayer.xcodeproj -scheme AudioPlayer -configuration Debug -destination 'platform=iOS Simulator,name=Any iOS Simulator Device'

# Build for device (requires provisioning profile)
xcodebuild -project AudioPlayer.xcodeproj -scheme AudioPlayer -configuration Release -destination 'generic/platform=iOS'

# Clean build folder
xcodebuild clean -project AudioPlayer.xcodeproj -scheme AudioPlayer
```

### Testing
```bash
# Run unit tests
xcodebuild test -project AudioPlayer.xcodeproj -scheme AudioPlayer -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run specific test class
xcodebuild test -project AudioPlayer.xcodeproj -scheme AudioPlayer -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:AudioPlayerTests/AudioPlayerTests

# Run UI tests
xcodebuild test -project AudioPlayer.xcodeproj -scheme AudioPlayerUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# List available simulators
xcrun simctl list devices available
```

### Opening in Xcode
```bash
# Open project in Xcode
open AudioPlayer.xcodeproj
```

## Architecture & Code Structure

### Core Data Architecture
The app uses Core Data for persistent storage with four main entities:

#### AudioFile Entity
- `id: UUID` - Unique identifier
- `title: String?` - Track title
- `artist: String?` - Artist name
- `album: String?` - Album name
- `genre: String?` - Music genre
- `fileName: String` - Original filename
- `filePath: String` - Path to audio file
- `artworkPath: String?` - Path to artwork image
- `duration: Double` - Track duration in seconds
- `currentPosition: Double` - Last playback position
- `fileSize: Int64` - File size in bytes
- `dateAdded: Date` - Import date
- `lastPlayed: Date?` - Last played timestamp
- `playCount: Int32` - Number of times played
- Relationship: `folder` (to-one with Folder)

#### Folder Entity (Hierarchical Organization)
- `id: UUID` - Unique identifier
- `name: String` - Folder name
- `path: String` - Folder path
- `dateAdded: Date` - Creation date
- `fileCount: Int32` - Cached count of audio files
- Relationships:
  - `audioFiles` (to-many with AudioFile) - Files in this folder
  - `parentFolder` (to-one with Folder) - Parent folder (nil for root)
  - `subFolders` (to-many with Folder) - Child folders

#### Playlist Entity
- `id: UUID` - Unique identifier
- `name: String` - Playlist name
- `dateCreated: Date` - Creation timestamp
- `dateModified: Date` - Last modification
- Relationship: `playlistItems` (to-many with PlaylistItem)

#### PlaylistItem Entity
- `id: UUID` - Unique identifier
- `order: Int32` - Position in playlist
- `dateAdded: Date` - When added to playlist
- Relationships:
  - `audioFile` (to-one with AudioFile) - Referenced audio file
  - `playlist` (to-one with Playlist) - Parent playlist

**PersistenceController**: Manages Core Data stack with preview support for SwiftUI previews

## Technical Requirements

### Dependencies & Requirements
- **Minimum iOS Version**: iOS 26.0+
- **Swift Version**: Swift 5.0
- **External Dependencies**: None (uses only system frameworks)
- **System Frameworks**:
  - SwiftUI (UI framework)
  - AVFoundation (audio playback)
  - CoreData (persistence)
  - MediaPlayer (remote controls)
  - UniformTypeIdentifiers (file type handling)
  - UIKit (minimal usage for accessibility and system integration)

### SwiftUI + MVVM Pattern
The app follows MVVM architecture with comprehensive ObservableObject services:
- **AudioPlayerService**: Handles audio playback, background audio, media remote controls, and playlist queue management
- **AudioFileManager**: Manages file import, metadata extraction, storage operations, and folder hierarchy processing
- **AccessibilityManager**: Manages VoiceOver announcements, accessibility settings, sleep timer, and touch target validation
- **SettingsManager**: Manages app settings, language preferences, and playbook speed defaults
- **PlaylistManager**: Handles playlist creation, management, reordering, and playback queue
- **FolderNavigationManager**: Manages hierarchical folder navigation and breadcrumb tracking
- **LocalizationManager**: Provides comprehensive localization support with L() convenience functions

### Pure SwiftUI Architecture
The app is built with **100% SwiftUI** and uses modern SwiftUI patterns:
- **SwiftUI App Lifecycle**: Uses `@main struct AudioPlayerApp: App` (no AppDelegate/SceneDelegate)
- **No Storyboards**: Pure SwiftUI navigation with NavigationStack and TabView
- **SwiftUI-First**: All views are built with SwiftUI components
- **Minimal UIKit**: UIKit is only used for essential system integrations (accessibility APIs, share sheets)

### Tab-Based Navigation
Four main tabs implemented in `ContentView`:
1. **Library** (`LibraryGridView`): Hierarchical folder navigation with Grid/List view modes
2. **Playlist** (`PlaylistView`): Playlist management with reordering and queue playback
3. **Player** (`AudioPlayerView`): Full-screen audio player with speed control and sleep timer
4. **Settings** (`SettingsView`): App configuration, accessibility settings, and language selection

### Hierarchical Folder Navigation
Sophisticated folder organization system:
- **Folder Import**: Automatically creates folder hierarchy during import
- **Breadcrumb Navigation**: Visual navigation path with tap-to-navigate
- **FolderNavigationManager**: Tracks current location and navigation history
- **Mixed Content**: Each level can contain both subfolders and audio files
- **Folder Cards**: Visual representation with file/subfolder counts
- **Deep Navigation**: Unlimited nesting depth supported
- **Context Actions**: Delete folders with cascade delete of contents

### Library View Modes
Flexible viewing options in `LibraryGridView`:
- **Grid Mode**: 2-column LazyVGrid with large artwork thumbnails
- **List Mode**: Vertical list with compact layout and dividers
- **Toggle Button**: Animated switch between view modes
- **Consistent Actions**: Same context menu actions in both modes
- **Dynamic Type Support**: Adaptive sizing based on accessibility text size
- **Performance Optimized**: LazyVGrid and LazyVStack for large libraries

### Audio Import System
Sophisticated import pipeline in `AudioFileManager` with comprehensive processing:

#### Import Capabilities
- **Individual Files**: Single audio file import with metadata extraction
- **Folder Recursion**: Deep folder scanning with hierarchy preservation
- **Mixed Selection**: Combined file and folder import in single operation
- **Drag & Drop**: Support for dragging files/folders into the app
- **Document Picker**: System file picker with multi-selection

#### Processing Pipeline
- **Format Validation**: Supports MP3, M4A, M4B, AAC, WAV, FLAC, AIFF, CAF
- **Metadata Extraction**: Uses AVFoundation for title, artist, album, duration, genre
- **Artwork Processing**: Extracts embedded artwork and saves to dedicated directory
- **Duplicate Detection**: Prevents importing the same file multiple times
- **Security Handling**: Proper security-scoped resource management for sandboxing
- **UUID Naming**: Files renamed with UUIDs to prevent conflicts
- **Progress Tracking**: Real-time import progress with detailed results

#### Import Results
- **Success Reporting**: Count of successfully imported files
- **Failure Handling**: Detailed error reporting for failed imports
- **Result Dialog**: User-friendly summary with option to view detailed results
- **Accessibility Announcements**: VoiceOver feedback for import completion

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
.environmentObject(playlistManager)
.environmentObject(accessibilityManager)
```

### Internationalization & Localization
Comprehensive localization system with `LocalizationManager`:
- **Supported Languages**: English (en), Spanish (es) with extensible architecture
- **L() Function**: Convenient access to localized strings throughout the app
- **Dynamic Language Switching**: Runtime language changes without restart
- **Accessibility Localization**: Specialized strings for VoiceOver and accessibility features
- **Parameterized Strings**: Support for formatted strings with arguments
- **Settings Integration**: Language selection in Settings tab with immediate UI updates
- **Bundle Management**: Automatic language bundle loading and fallback to English

### Playlist System
Advanced playlist management with queue-based playback:
- **PlaylistManager**: Handles playlist creation, modification, and playback queue
- **Reorderable Items**: Drag-and-drop reordering with automatic order updating
- **Queue Playbook**: Sequential playback with continuous play support
- **Add to Playlist**: Bulk addition of selected files with duplicate prevention
- **Cascade Delete**: Automatic playlist cleanup when audio files are deleted
- **Playlist Duration**: Calculated total duration display
- **Resume Position**: Maintains playback position within playlists
- **Background Integration**: Full background playback support with remote controls

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

## Recent Changes & Design Decisions

### Major Performance Optimizations (October 2025)
- **Critical CPU Performance Fix**: Resolved severe performance issue reducing CPU usage from 120% to 51% (57.5% improvement)
  - **Timer Optimization**: Reduced AudioPlayerService timer frequency from 0.25s to 1.0s (75% reduction in updates)
  - **Eliminated Cascading Updates**: Removed expensive `.onChange(of: audioPlayerService.currentTime)` listeners from individual audio file cards
  - **Smart Progress Calculation**: Only calculate real-time progress for currently playing file, use cached position for others
  - **Simplified Update Logic**: Streamlined `updateCurrentTime()` method with better throttling and main thread handling

- **SwiftUI View Complexity Resolution**: Fixed severe view hierarchy complexity causing potential crashes
  - **Component Extraction**: Created reusable `GlassButton` and simplified `GlassMorphismButton` components
  - **View Decomposition**: Broke down `bookArtworkWithDetails` into `artworkBackground`, `gradientOverlay`, and `bookDetailsOverlay`
  - **Reduced Nesting Depth**: Simplified deeply nested view structures from 10+ levels to 2-3 levels
  - **Eliminated Complex Modifiers**: Replaced multiple overlapping gradients and shadows with simpler, efficient alternatives

- **Energy Impact Improvement**: Moved from "High" to "Low" energy consumption category
  - **Better Battery Life**: Significantly reduced background processing overhead
  - **Thermal Performance**: Reduced heat generation from excessive CPU usage
  - **Memory Optimization**: Improved allocation patterns with less frequent garbage collection

- **Code Modernization**: Updated deprecated APIs for iOS 17+ compatibility
  - **onChange Syntax**: Updated to modern two-parameter or zero-parameter closure syntax
  - **String Formatting**: Fixed string interpolation with specifier syntax
  - **Build Warnings**: Resolved all performance-related compiler warnings

### UI Design & Theming (September 2025)
- **Black Backgrounds**: Updated all gray background colors to black for better visual consistency
  - `LibraryGridView.swift`: Changed `.systemGray6` fills to `.black`
  - `FolderCardView.swift`: Recreated with black backgrounds throughout
  - Enhanced high-contrast accessibility support with black-based theming
- **Consistent Design Language**: Unified color scheme across all UI components

### SwiftUI Purification (September 2025)
- **Removed Storyboard Dependencies**: Eliminated all storyboard-based UI components
  - Removed `UISceneStoryboardFile` and `UISceneDelegateClassName` from Info.plist
  - Simplified scene configuration for pure SwiftUI app lifecycle
  - No AppDelegate.swift or SceneDelegate.swift files
- **UIKit Minimization**: Reduced UIKit usage to essential system integrations only
  - Accessibility APIs (`UIAccessibility` for VoiceOver support)
  - System share sheets (`UIActivityViewController`)
  - Focus management for accessibility features

### File Storage Considerations
- **iCloud Storage Issues**: Be aware that files stored in iCloud Drive may cause build timeouts
- **Recommended**: Keep active development projects in local directories outside of iCloud sync
- **Build Issues**: If experiencing file timeout errors, check for `compressed,dataless` file attributes

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

## Troubleshooting

### Build Issues

**File Timeout Errors**:
- If you encounter "Operation timed out" errors during build:
  - Check if files are stored in iCloud Drive with "Optimize Mac Storage"
  - Use `ls -lO filename` to check for `compressed,dataless` attributes
  - Move project to local directory outside iCloud sync
  - Use Xcode IDE instead of command line tools

**Simulator Not Found**:
- Use `xcrun simctl list devices available` to list available simulators
- Update destination names in build commands to match available simulators
- Use `'platform=iOS Simulator,name=Any iOS Simulator Device'` for flexibility

**Asset Compilation Warnings**:
- Missing app icons will show warnings but won't prevent builds
- Icons are located in `AudioPlayer/Assets.xcassets/AppIcon.appiconset/`
- Warnings can be ignored for development builds

### Development Environment
- **Recommended**: Use Xcode IDE for development and debugging
- **File Storage**: Keep projects in local directories (not iCloud Drive)
- **Simulators**: Ensure iOS simulators are installed and updated via Xcode

## Performance Best Practices

### Timer Management
- **Conservative Frequencies**: Use 1Hz (1 second) or slower for UI updates; avoid sub-second intervals unless absolutely necessary
- **Background Adaptation**: Reduce timer frequency significantly when app is in background (5+ seconds)
- **Proper Cleanup**: Always invalidate timers in deinit and when stopping playback
- **Weak References**: Use `[weak self]` in timer closures to prevent retain cycles

### SwiftUI Optimization
- **View Complexity**: Keep view builders simple; extract complex nested structures into separate components
- **onChange Usage**: Minimize `.onChange` listeners, especially on frequently updating properties like `currentTime`
- **Progress Updates**: Only calculate real-time progress for active/playing items; use cached values for inactive items
- **Component Reuse**: Extract reusable components instead of duplicating complex view code

### Memory Management
- **State Throttling**: Throttle @Published property updates to prevent excessive view re-renders
- **Image Loading**: Use efficient image loading with proper caching and fallbacks
- **Core Data**: Optimize fetch requests and avoid frequent context saves during playback

### Energy Efficiency
- **Update Frequency**: Balance UI responsiveness with battery life; 1-second updates are usually sufficient
- **Background Processing**: Minimize CPU-intensive operations when app is backgrounded
- **Network Usage**: Cache metadata and artwork to reduce repeated network requests
