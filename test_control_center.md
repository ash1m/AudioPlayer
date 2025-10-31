# Control Center Test Steps

## Testing Procedure

To verify that the Control Center and Lock Screen controls are working properly after the fixes:

### 1. Build and Run the App
```bash
cd /Users/ashim/Documents/AICoding/AudioPlayer
xcodebuild -project AudioPlayer.xcodeproj -scheme AudioPlayer -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build
```

### 2. Test Control Center Activation
1. Launch the app on device/simulator
2. Import and load an audio file
3. Start playback
4. Check console output for these key messages:
   - "✅ Audio session activated successfully"
   - "✅ All remote transport controls configured"
   - "✅ Now Playing info set for loaded track"
   - "✅ Successfully set Now Playing info with X properties"

### 3. Test Lock Screen Controls
1. Start audio playback in the app
2. Lock the device (press power button)
3. Wake the device (but don't unlock)
4. Check if media controls appear on lock screen
5. Test play/pause, skip forward/backward buttons

### 4. Test Control Center Controls
1. With audio playing, swipe up from bottom (or down from top-right on newer devices)
2. Verify media controls appear in Control Center
3. Test all control functions:
   - Play/Pause
   - Skip Forward (+15s)
   - Skip Backward (-15s)
   - Scrub bar (seek)
   - Track info display

### 5. Test Remote Command Functionality
Verify console output shows commands being received:
- "▶️ Remote play command received"
- "⏸️ Remote pause command received"

## Expected Results

✅ **Success Indicators:**
- Lock screen shows media controls when audio is playing
- Control Center displays track info and controls
- All remote commands work properly
- Console shows successful setup messages
- No audio session errors in console

❌ **Failure Indicators:**
- No controls appear on lock screen
- Control Center shows no media controls
- Audio session setup errors in console
- "❌ Failed to set Now Playing info!" in logs
- Remote commands not responding

## Common Issues and Solutions

### Issue: Controls appear but don't respond
- **Cause**: Remote command center targets not set properly
- **Solution**: Check console for "Remote X command received" messages

### Issue: Controls don't appear at all
- **Cause**: Audio session not active or Now Playing info not set
- **Solution**: Verify audio session activation and Now Playing info in logs

### Issue: Controls appear briefly then disappear
- **Cause**: Conflicting Now Playing info updates
- **Solution**: Check for multiple rapid updateNowPlayingInfo() calls

### Issue: Seek bar doesn't work
- **Cause**: Invalid duration or elapsed time values
- **Solution**: Verify displayDuration > 0 and displayElapsedTime is within bounds