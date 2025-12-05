# Critical Requirements Checklist

This document lists the 4 critical requirements for Control Center and lock screen media widget functionality to work properly.

## 1. Audio Session Category Must Be .playback

### ✅ What it means
The app's AVAudioSession must have its category set to `.playback` so iOS knows the app plays audio and can show it in Control Center.

### 🔍 How to verify in console
Look for this on app startup:
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
✅ [MediaControls] Audio session ready for Control Center/Lock Screen
```

### ❌ Error if missing
```
🔧 [MediaControls] ========== AUDIO SESSION DIAGNOSTIC ===========
   Current category: soloAmbient
   ...
❌ [MediaControls] ========== AUDIO SESSION ERROR ===========
   Failed to configure audio session
   IMPACT: Control Center may not appear
```

### 📝 How to fix
The code automatically sets this in `MediaControlsManager.ensureAudioSessionActive()`:
```swift
try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
```

This is called when:
- App starts (via setupAudioSession)
- Audio file is loaded
- Before playback starts

---

## 2. UIBackgroundModes → audio in Info.plist

### ✅ What it means
iOS needs to know the app plays audio in the background. This is declared in Info.plist with UIBackgroundModes.

### 🔍 How to verify in console
Look for this on app startup:
```
🚀 [MediaControls] ========== STARTUP VALIDATION ===========
   Checking critical requirements...

   ✅ CHECK 2: UIBackgroundModes contains 'audio' in Info.plist
   Background modes: ["remote-notification", "audio", "fetch", "processing"]
```

### ❌ Error if missing
```
   ❌ CHECK 2: UIBackgroundModes does NOT contain 'audio'
   Available modes: ["remote-notification", "fetch"]
   FIX: Add <string>audio</string> to UIBackgroundModes in Info.plist
```

OR

```
   ❌ CHECK 2: UIBackgroundModes not found in Info.plist
   FIX: Add UIBackgroundModes array with 'audio' entry to Info.plist
```

### 📝 How to verify manually
1. Open `Info.plist` in Xcode
2. Look for key: `UIBackgroundModes`
3. Should be an array containing: `audio`

Current status in this project: ✅ **VERIFIED** 
- Lines 36-42 in Info.plist contain audio in UIBackgroundModes

---

## 3. Now Playing Info Must Be Updated

### ✅ What it means
When audio is playing, the app must send metadata (title, artist, album, duration, etc.) to `MPNowPlayingInfoCenter` so Control Center knows what to display.

### 🔍 How to verify in console
Look for this when you start playing audio:
```
🎵 [MediaControls] ========== UPDATING NOW PLAYING INFO ===========
   Title: Track Name
   Artist: Artist Name
   Album: Album Name
   Duration: 180.50s
   Current Time: 0.00s
   Is Playing: true
   Playback Rate: 1.0x

   Building Now Playing Dictionary with 7 base properties...
   ✅ Artwork added (300x300px)

   Setting to MPNowPlayingInfoCenter...
   ✅ Now Playing info set successfully
   Verified properties: 8
   - Title: Track Name
   - Artist: Artist Name
   - Album: Album Name
   - Duration: 180.5s
   - Elapsed: 0.0s
   - Rate: 1.0
   - Has Artwork: true
✅ [MediaControls] Control Center/Lock Screen should now display
```

### ❌ Error if not updated
```
   ❌ DIAGNOSTIC: Failed to set Now Playing info
   MPNowPlayingInfoCenter.nowPlayingInfo is nil
   Control Center and lock screen will NOT display
```

### ❌ Error if invalid duration
```
❌ [MediaControls] DIAGNOSTIC: Cannot update Now Playing with invalid duration: 0.0
   Title: Track Name
   Artist: Artist Name
```

### 📝 How to fix
Check that:
1. Duration is > 0 (not 0 or negative)
2. Metadata (title, artist) are not nil or empty
3. Message "UPDATING NOW PLAYING INFO" appears when you play

If not updating:
- Check that `play()` method is being called
- Verify `updateNowPlayingInfo()` is being called from play()
- Check console for any error messages

---

## 4. Remote Command Handlers Must Be Registered

### ✅ What it means
The app must register handlers with `MPRemoteCommandCenter` so iOS can tell the app when user taps play/pause in Control Center or lock screen.

### 🔍 How to verify in console
Look for this on app startup:
```
🎵 [MediaControls] ========== INITIALIZING MEDIA CONTROLS ===========
   ✅ Play command configured - isEnabled: true
   ✅ Pause command configured - isEnabled: true
   ✅ Toggle Play/Pause command configured - isEnabled: true
   ✅ Skip Forward: true | Backward: true
   ✅ Next/Previous - Next: true | Prev: true
   ✅ Playback position seeking - isEnabled: true

✅ [MediaControls] All remote commands configured and ready
   Registered commands:
   - Play/Pause/Toggle: Enabled
   - Skip Forward/Backward: Enabled
   - Next/Previous Track: Enabled
   - Playback Position: Enabled
```

Then when you tap play/pause, look for:
```
▶️ [MediaControls] ⚡ PLAY COMMAND RECEIVED FROM CONTROL CENTER/LOCK SCREEN ⚡
   ✅ Play command forwarded to audio player

⏸️ [MediaControls] ⚡ PAUSE COMMAND RECEIVED FROM CONTROL CENTER/LOCK SCREEN ⚡
   ✅ Pause command forwarded to audio player
```

### ❌ Error if not registered
Missing:
- No "INITIALIZING MEDIA CONTROLS" message
- Commands show `isEnabled: false`
- No "⚡ COMMAND RECEIVED" messages when tapping controls

### ❌ Error if delegate not set
```
⚠️ [MediaControls] No delegate set for handling commands
```

Should see this instead:
```
🔗 [MediaControls] Delegate registered: AudioPlayerService
   Remote commands will now be routed to: AudioPlayerService
   Control Center/Lock Screen interactions enabled
```

### 📝 How to fix
Verify:
1. `setupRemoteCommands()` is being called during app startup
2. All command handlers show `isEnabled: true`
3. Delegate is registered: "Delegate registered: AudioPlayerService"
4. User taps are being received: "⚡ COMMAND RECEIVED" messages

If commands not being received:
- Check Info.plist has `UIBackgroundModes` with `audio`
- Check audio session is set to `.playback`
- Check Now Playing info is set
- Verify app is not in background when testing

---

## Complete Startup Verification Flow

When app starts, you should see IN ORDER:

### 1. Startup Validation
```
🚀 [MediaControls] ========== STARTUP VALIDATION ===========
   ✅ CHECK 1: Audio session category is .playback
   ✅ CHECK 2: UIBackgroundModes contains 'audio' in Info.plist
   ⚠️ CHECK 3: Now Playing info is not yet set (expected during startup)
   ✅ CHECK 4: Remote commands will be configured in setupRemoteCommands()
========================================
```

### 2. Audio Session Setup
```
🔧 [MediaControls] ========== AUDIO SESSION DIAGNOSTIC ===========
   ✅ Category set to: .playback
   ✅ Audio session activated
✅ [MediaControls] Audio session ready for Control Center/Lock Screen
```

### 3. Remote Commands Setup
```
🎵 [MediaControls] ========== INITIALIZING MEDIA CONTROLS ===========
   ✅ Play command configured - isEnabled: true
   ✅ Pause command configured - isEnabled: true
   ✅ Toggle Play/Pause command configured - isEnabled: true
   [... more commands ...]
✅ [MediaControls] All remote commands configured and ready
```

### 4. Delegate Registration
```
🔗 [MediaControls] Delegate registered: AudioPlayerService
   Remote commands will now be routed to: AudioPlayerService
```

If you see all 4 sections, the app is ready for Control Center!

---

## Troubleshooting by Symptom

### Symptom: Control Center Doesn't Show

**Possible Causes:**
1. Audio session not `.playback` → Look for "AUDIO SESSION ERROR"
2. UIBackgroundModes missing "audio" → Look for "CHECK 2: UIBackgroundModes does NOT contain"
3. Now Playing info not set → Look for "Failed to set Now Playing info"
4. Commands not registered → Look for missing "INITIALIZING MEDIA CONTROLS"

**How to fix:**
- Check startup messages for ✅ or ❌ indicators
- If ❌, the error message will tell you what to fix
- If ⚠️, it's expected (will be set when audio plays)

### Symptom: Control Center Shows But Buttons Don't Work

**Possible Causes:**
1. Commands not registered → Check "isEnabled: true" for all commands
2. Delegate not set → Look for "Delegate registered" message
3. Commands not being received → Don't see "⚡ COMMAND RECEIVED" when tapping

**How to fix:**
- If no "COMMAND RECEIVED" messages, audio session may not be active
- Try playing audio, then tapping Control Center
- Check console for errors when tapping

### Symptom: No Console Messages At All

**Possible Causes:**
1. Filtering might be hiding messages
2. App crashed during startup
3. MediaControlsManager not initialized

**How to fix:**
- Clear Xcode console
- Search for `[MediaControls]` in console
- Rebuild and run app
- Check for crash logs

---

## Quick Reference

| Requirement | Check For | Should See | If Missing |
|---|---|---|---|
| Audio session .playback | Category check | "Category set to: .playback" | "AUDIO SESSION ERROR" |
| UIBackgroundModes audio | Info.plist check | "UIBackgroundModes contains 'audio'" | "does NOT contain 'audio'" |
| Now Playing updated | Play any audio | "UPDATING NOW PLAYING INFO" | "Failed to set Now Playing info" |
| Commands registered | App startup | "All remote commands configured" | No remote command messages |

---

## When to Check Each Requirement

1. **At app startup:** All 4 checks should appear in order
2. **When loading audio:** Now Playing info should update
3. **When playing audio:** Should see periodic "UPDATING NOW PLAYING INFO"
4. **When tapping Control Center:** Should see "⚡ COMMAND RECEIVED"
5. **When stopping audio:** Should see "CLEARING NOW PLAYING INFO"

