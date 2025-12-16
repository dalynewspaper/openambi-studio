# OpenAmbi: iOS Deployment Guide

This guide covers deploying OpenAmbi as a native iOS app with background audio support. Since this is already a native Swift app, we don't need Capacitor - we can configure background audio directly.

## Core Requirements

**Why Background Audio?**
- On iOS, audio stops immediately when the screen turns off or the user switches apps (unless configured for background playback)
- For a sleep/focus application, continuous audio playback is critical
- We need to enable "Audio Background Mode" in Xcode

## Code Configuration (Already Completed)

The `AudioManager.swift` has been updated with:
- ✅ Background audio session configuration (`.playback` category)
- ✅ Remote control events for lock screen controls
- ✅ Audio mixing with other apps (`.mixWithOthers` option)

## Xcode Configuration Steps

### 1. Open Your Project in Xcode

```bash
open openambi-studio.xcodeproj
```

### 2. Enable Background Modes Capability

This is the **most critical step** for background audio:

1. **Select your app target:**
   - Click on the project name in the left sidebar
   - Select the `openambi-studio` target

2. **Go to Signing & Capabilities tab:**
   - Click on the "Signing & Capabilities" tab at the top

3. **Add Background Modes capability:**
   - Click the "+ Capability" button (top left)
   - Search for "Background Modes"
   - Double-click to add it

4. **Enable Audio, AirPlay, and Picture in Picture:**
   - Check the box: **"Audio, AirPlay, and Picture in Picture"**
   - This allows your app to play audio in the background

### 3. Configure Info.plist (if needed)

Modern Xcode projects embed Info.plist settings. If you need to add custom settings:

1. Right-click on your project in the navigator
2. Select "New File" → "Property List"
3. Name it `Info.plist` (if it doesn't exist)
4. Add the following key if needed:
   - Key: `UIBackgroundModes`
   - Type: Array
   - Value: `audio`

**Note:** The Background Modes capability in Xcode automatically handles this, so you typically don't need to manually edit Info.plist.

### 4. Audio Session Configuration

The `AudioManager` is already configured with:
- Category: `.playback` (allows background audio)
- Options: `.mixWithOthers` (plays alongside other audio)
- Options: `.allowAirPlay` (supports AirPlay)

This configuration ensures:
- Audio continues when the screen locks
- Audio continues when switching apps
- Audio can play alongside other music apps (if user wants)

## Testing Background Audio

### On Simulator:
1. Build and run the app (⌘R)
2. Start playing audio
3. Lock the simulator (Device → Lock, or ⌘L)
4. Audio should continue playing

### On Physical Device:
1. Connect your iPhone via USB
2. Select your device in Xcode's device menu
3. Build and run (⌘R)
4. Start playing audio
5. Lock your phone (press the side button)
6. Audio should continue playing
7. You should see media controls on the lock screen

## Lock Screen Controls

The app is configured to show media controls on the lock screen:
- Play/Pause button
- Track information (if configured)
- Volume controls

## Troubleshooting

### Audio stops when screen locks:
- ✅ Verify Background Modes capability is enabled
- ✅ Check that "Audio, AirPlay, and Picture in Picture" is checked
- ✅ Ensure `AudioManager.setupAudioSession()` is called on app launch
- ✅ Test on a physical device (simulator may have limitations)

### No lock screen controls:
- ✅ Verify `UIApplication.shared.beginReceivingRemoteControlEvents()` is called
- ✅ Check that audio is actually playing
- ✅ Ensure the app has proper audio session configuration

### Audio conflicts with other apps:
- The `.mixWithOthers` option allows mixing
- If you want exclusive audio, remove `.mixWithOthers` from the options

## Build and Deploy

### For Development:
1. Connect your iPhone
2. Select your device in Xcode
3. Press ⌘R to build and run

### For App Store:
1. Select "Any iOS Device" or a generic iOS device
2. Product → Archive
3. Follow the App Store Connect workflow

## Additional Notes

- **Background audio requires a valid Apple Developer account** for testing on physical devices
- **App Store submission** will require justification for background audio usage (sleep/focus app is a valid use case)
- The app will show a badge in the status bar when playing audio in the background (this is normal iOS behavior)

## Next Steps

1. ✅ Enable Background Modes in Xcode (see step 2 above)
2. ✅ Test on a physical device
3. ✅ Verify lock screen controls work
4. ✅ Test with screen locked for extended periods
5. ✅ Prepare App Store description explaining background audio usage

---

**Important:** The Background Modes capability must be enabled in Xcode for background audio to work. This cannot be done programmatically - it must be configured in the Xcode project settings.

