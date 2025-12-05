# Media Controls Diagnostic Logging Guide

This document explains the diagnostic output you'll see in the Xcode console when testing Control Center and lock screen media widget functionality.

## Search Filter for Console

To easily find all media control diagnostics in the console, search for:
```
[MediaControls]
```

## Diagnostic Categories

### 1. App Startup - Remote Commands Configuration

When the app starts, you should see:

```
🎵 [MediaControls] ========== INITIALIZING MEDIA CONTROLS ===========
   Setting up MPRemoteCommandCenter...
   ✅ All previous command targets cleared
   ✅ Play command configured
   ✅ Pause command configured
   ✅ Toggle Play/Pause command configured (lock screen)
   ✅ Skip Forward/Backward commands configured
   ✅ Next/Previous track commands configured
   ✅ Playback position seeking configured

✅ [MediaControls] All remote commands configured and ready
   Now Playing info updates will appear in:
   - Control Center
   - Lock screen media widget
   - Headphone controls
========================================
```

**What it means:** Remote commands are ready to receive input from Control Center and lock screen.

---

### 2. Delegate Registration

After app initializes:

```
🔗 [MediaControls] Delegate registered: AudioPlayerService
   Remote commands will now be routed to: AudioPlayerService
   Control Center/Lock Screen interactions enabled
```

**What it means:** The audio player service is now listening for remote commands.

---

### 3. Audio Session Setup

```
🔧 [MediaControls] ========== AUDIO SESSION DIAGNOSTIC ===========
   Current category: playback
   Current mode: default
   ✅ Category set to: .playback
   ✅ Options set to: [.mixWithOthers]
   ✅ Audio session activated

   Verification:
   - Category: playback
   - Mode: default
   - Is Other Audio Playing: false
✅ [MediaControls] Audio session ready for Control Center/Lock Screen
========================================
```

**What it means:** Audio session is properly configured. Control Center can now communicate with the app.

**If you see an error instead:**
```
❌ [MediaControls] ========== AUDIO SESSION ERROR ===========
   Failed to configure audio session
   Error: [error details]
   IMPACT: Control Center may not appear
========================================
```

---

### 4. Loading and Playing Audio

When you load and play a track:

```
🎵 [MediaControls] ========== UPDATING NOW PLAYING INFO ===========
   Title: My Song Title
   Artist: Artist Name
   Album: Album Name
   Duration: 180.50s
   Current Time: 0.00s
   Is Playing: true
   Playback Rate: 1.0x
   Playback Rate (for CC): 1.0
   Has Artwork: true

   Building Now Playing Dictionary with 7 base properties...
   ✅ Artwork added (300x300px)

   Setting to MPNowPlayingInfoCenter...
   ✅ Now Playing info set successfully
   Verified properties: 8
   - Title: My Song Title
   - Artist: Artist Name
   - Album: Album Name
   - Duration: 180.5s
   - Elapsed: 0.0s
   - Rate: 1.0
   - Has Artwork: true
   - Media Type: 1
✅ [MediaControls] Control Center/Lock Screen should now display
========================================
```

**What it means:** Track metadata has been sent to the system. Control Center and lock screen should now show the player widget.

**If artwork isn't found:**
```
   ⚠️ No artwork provided
```

**If update fails:**
```
   ❌ DIAGNOSTIC: Failed to set Now Playing info
   MPNowPlayingInfoCenter.nowPlayingInfo is nil
   Control Center and lock screen will NOT display
```

---

### 5. Playing, Pausing, and Seeking

During playback, you should see periodic updates (controlled by playback time observers):

```
🎵 [MediaControls] ========== UPDATING NOW PLAYING INFO ===========
   Title: My Song Title
   Artist: Artist Name
   Album: Album Name
   Duration: 180.50s
   Current Time: 5.32s
   Is Playing: true
   Playback Rate: 1.0x
   Playback Rate (for CC): 1.0
   Has Artwork: true
   [... verification details ...]
✅ [MediaControls] Control Center/Lock Screen should now display
========================================
```

---

### 6. User Interactions - Control Center Commands

When you tap Play/Pause in Control Center:

```
▶️ [MediaControls] ⚡ PLAY COMMAND RECEIVED FROM CONTROL CENTER/LOCK SCREEN ⚡
   ✅ Play command forwarded to audio player

⏸️ [MediaControls] ⚡ PAUSE COMMAND RECEIVED FROM CONTROL CENTER/LOCK SCREEN ⚡
   ✅ Pause command forwarded to audio player

🔄 [MediaControls] ⚡ TOGGLE PLAY/PAUSE RECEIVED FROM LOCK SCREEN TAP ⚡
   ✅ Toggle command forwarded to audio player
```

**What it means:** User interaction was detected and forwarded to the player. Playback state should change immediately.

---

### 7. Stopping Playback

When you stop playing or clear the current file:

```
🔄 [MediaControls] ========== CLEARING NOW PLAYING INFO ===========
   Clearing existing Now Playing info...
   ✅ Successfully cleared
   Control Center and lock screen will be HIDDEN
========================================
```

**What it means:** Now Playing info has been removed. Control Center widget will disappear.

---

## Troubleshooting Checklist

Use this checklist with the diagnostic output to identify issues:

### ❌ Control Center Not Showing

1. **Check for initialization:**
   - Should see "INITIALIZING MEDIA CONTROLS" message
   - All commands should show "✅ configured"

2. **Check audio session:**
   - Should see "Audio session ready for Control Center/Lock Screen"
   - If you see "AUDIO SESSION ERROR", that's the problem

3. **Check delegate:**
   - Should see "Delegate registered: AudioPlayerService"

4. **Check Now Playing info:**
   - Should see "UPDATING NOW PLAYING INFO"
   - Should see "Control Center/Lock Screen should now display"
   - If you see "Failed to set Now Playing info", info isn't being set

### ❌ Control Center Commands Not Responding

1. **Check initialization:**
   - Confirm all commands are configured

2. **Check for command messages:**
   - Should see "⚡ PLAY COMMAND RECEIVED FROM CONTROL CENTER/LOCK SCREEN ⚡"
   - If missing, commands aren't reaching the app

3. **Check delegate:**
   - Should see "Delegate registered"
   - If missing, commands have nowhere to go

4. **Check command forwarding:**
   - Should see "✅ Play command forwarded to audio player"
   - If missing, command wasn't forwarded

### ⚠️ Information Shows But Controls Don't Work

1. Check command received messages - if they appear, the issue is in the audio player
2. Verify the delegate methods (play(), pause(), etc.) are being called
3. Check if AVPlayer is actually playing/pausing

## Tips for Using Diagnostics

1. **Filter console:** Use `[MediaControls]` filter to show only relevant messages
2. **Watch for emojis:** Different emojis indicate different operation types
   - 🎵 General updates
   - 🔧 Audio session operations
   - 🔗 Delegate operations
   - ⚡ Command received
   - ✅ Success
   - ❌ Error
   - ⚠️ Warning

3. **Look for separator lines:** Messages between "======" lines are grouped operations
4. **Check timestamps:** Console shows timestamps - useful for correlation with user actions
5. **Save output:** Copy diagnostic output when reporting issues

## Example Complete Flow

Here's what you should see for a successful play operation:

```
App Start:
- INITIALIZING MEDIA CONTROLS (all commands ✅)
- Delegate registered
- AUDIO SESSION DIAGNOSTIC (✅ ready)

User Loads Audio:
- UPDATING NOW PLAYING INFO (✅ display)

User Taps Play:
- ⚡ PLAY COMMAND RECEIVED (✅ forwarded)
- UPDATING NOW PLAYING INFO (playing: true, ✅ display)

User Taps Pause:
- ⚡ PAUSE COMMAND RECEIVED (✅ forwarded)
- UPDATING NOW PLAYING INFO (playing: false, ✅ display)

User Stops Playing:
- CLEARING NOW PLAYING INFO (✅ cleared, will hide)
```

If you see this complete flow, Control Center and lock screen are working correctly!
