# Widget, Shortcuts & Background Controls Setup Guide

This guide explains how to set up iOS widgets, Siri Shortcuts, and background controls for OpenAmbi.

## ✅ What's Already Implemented

### 1. Lock Screen & Control Center Controls
- ✅ Now Playing info (MPNowPlayingInfoCenter)
- ✅ Remote command center (play/pause/stop)
- ✅ Lock screen media controls
- ✅ Control Center integration

### 2. Widget Support
- ✅ Widget view code (`OpenAmbiWidget.swift`)
- ✅ Widget update service (`WidgetUpdateService.swift`)
- ✅ Integration with AudioManager

### 3. Siri Shortcuts
- ✅ Shortcut handling code (`OpenAmbiShortcuts.swift`)
- ✅ Intent donations for Siri suggestions
- ✅ App integration for shortcut handling

## 📱 Xcode Setup Required

### Step 1: Add Widget Extension Target

1. **Open Xcode:**
   ```bash
   open openambi-studio.xcodeproj
   ```

2. **Add Widget Extension:**
   - File → New → Target
   - Select "Widget Extension"
   - Name: `OpenAmbiWidgetExtension`
   - Language: Swift
   - Include Configuration Intent: No (we're using static configuration)

3. **Move Widget Files:**
   - Move `openambi-studio/Widgets/OpenAmbiWidget.swift` to the Widget Extension target
   - Ensure it's added to the Widget Extension target (not the main app)
   - **Important:** The widget file should be in the Widget Extension target's folder/group

4. **Configure Widget Scheme Environment Variable (REQUIRED for debugging):**
   - In Xcode, select the **Widget Extension scheme** (dropdown next to the play button, should show "OpenAmbiWidgetExtension")
   - Product → Scheme → Edit Scheme...
   - Select "Run" in the left sidebar
   - Go to the "Arguments" tab
   - Under "Environment Variables", click the "+" button
   - Add:
     - **Name:** `_XCWidgetKind`
     - **Value:** `OpenAmbiWidgetExtension` (this should match your Widget Extension target name)
   - Click "Close"
   - **Important:** This environment variable is required for Xcode to properly debug and preview widgets. Without it, you'll get errors when trying to show the widget.

5. **Configure App Group:**
   - Select the main app target → Signing & Capabilities
   - Add "App Groups" capability
   - Create group: `group.com.openambi.studio`
   - Select the Widget Extension target
   - Add the same "App Groups" capability
   - Select the same group: `group.com.openambi.studio`

### Step 2: Update Info.plist

Add to the main app's `Info.plist`:

```xml
<key>NSUserActivityTypes</key>
<array>
    <string>INPlayMediaIntent</string>
    <string>INPauseMediaIntent</string>
    <string>INStopMediaIntent</string>
</array>
```

### Step 3: Create Intent Definition File (Optional - for custom shortcuts)

1. File → New → File
2. Select "SiriKit Intent Definition File"
3. Name: `OpenAmbiIntents.intentdefinition`
4. Add custom intents:
   - Play Ambient Sounds
   - Pause Ambient Sounds
   - Stop All Sounds
   - Set Master Volume

## 🎯 Features

### Lock Screen Controls

When audio is playing, users will see:
- **Play/Pause button** on lock screen
- **Track information** (active sound names)
- **Volume controls** in Control Center
- **Now Playing widget** in Control Center

### Home Screen Widget

The widget shows:
- **Playing/Paused status** with indicator
- **Active track count**
- **Master volume percentage**
- **Beautiful gradient background** matching app theme

### Siri Shortcuts

Users can:
- Say "Hey Siri, play OpenAmbi" to start playback
- Say "Hey Siri, pause OpenAmbi" to pause
- Say "Hey Siri, stop OpenAmbi" to stop all sounds
- Create custom shortcuts in Shortcuts app

## 🔧 Testing

### Test Lock Screen Controls:
1. Start playing audio in the app
2. Lock your iPhone
3. Wake the screen (don't unlock)
4. You should see media controls with play/pause

### Test Widget:
1. **Important:** Widgets must be tested on a **physical device** (not simulator)
2. Build and run the Widget Extension target on your device
3. Long press on Home Screen
4. Tap "+" to add widget
5. Search for "OpenAmbi"
6. Add widget to Home Screen
7. Widget should show current playback state
8. **If you see errors about `_XCWidgetKind`:** Make sure you've set the environment variable in the Widget Extension scheme (see Step 4 above)

### Test Siri Shortcuts:
1. Open Settings → Siri & Search
2. Find OpenAmbi in the list
3. Enable "Use with Ask Siri"
4. Say "Hey Siri, play OpenAmbi"
5. Or create custom shortcuts in Shortcuts app

## 📝 Code Integration

The following methods automatically update widgets and Now Playing info:

- `AudioManager.play()` - Updates widget and Now Playing
- `AudioManager.pause()` - Updates widget and Now Playing
- `AudioManager.updateMasterVolume()` - Updates widget
- `AudioManager.toggleTrack()` - Updates widget when tracks change

## 🚀 Next Steps

1. ✅ Add Widget Extension target in Xcode
2. ✅ Configure App Groups for data sharing
3. ✅ Test on physical device (widgets don't work in simulator)
4. ✅ Submit to App Store (widgets require App Store review)

## ⚠️ Important Notes

- **Widgets require iOS 14+**
- **Siri Shortcuts require iOS 12+**
- **Lock screen controls work on all iOS versions**
- **Widgets must be tested on a physical device** (simulator has limitations)
- **App Groups must match exactly** between app and widget extension

## 🎨 Customization

### Widget Appearance:
Edit `OpenAmbiWidgetView` in `OpenAmbiWidget.swift` to customize:
- Colors and gradients
- Layout and spacing
- Information displayed
- Widget sizes (small, medium, large)

### Shortcut Phrases:
Edit `OpenAmbiShortcuts.swift` to customize:
- Intent types
- Donation timing
- Response handling

---

**Status:** Code is ready. Xcode configuration required for full functionality.

