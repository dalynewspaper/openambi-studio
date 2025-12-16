# 🎯 OpenAmbi UX Design Rules

## Core Interaction Model: "Pull to Activate"

### Primary Gesture: Pull from Bottom
- **Sounds start at the bottom** of the screen in a "docked" state
- **Pull up** to activate and increase volume
- **Height = Volume**: The higher you pull, the louder it gets
- **Position = Spatial Audio**: Left/right position controls panning

---

## 📐 Visual Rules

### 1. Sound States

#### **Docked State** (Bottom of screen)
- Small, translucent orbs
- Arranged horizontally in a dock
- Shows icon only
- No particles, no glow
- Volume: 0%

#### **Active State** (Pulled up)
- Full-size orb with glow
- Particles emit from orb
- Waveform rings pulse
- Volume indicator shows percentage
- Volume: Based on height (0-100%)

#### **Maximum State** (Top of screen)
- Largest size
- Brightest glow
- Most particles
- Volume: 100%

### 2. Height-to-Volume Mapping

```
Screen Height (0-100%)
├── 0-10%:   Docked (inactive)
├── 10-30%:  Volume 0-30% (quiet)
├── 30-60%:  Volume 30-70% (medium)
├── 60-90%:  Volume 70-100% (loud)
└── 90-100%: Volume 100% (maximum)
```

### 3. Spatial Audio Rules

- **Left side** (0-40% of width): Pans left
- **Center** (40-60% of width): Centered
- **Right side** (60-100% of width): Pans right
- **Distance from center**: Controls reverb/depth

---

## 🎮 Interaction Rules

### Rule 1: Pull to Activate
- **Drag from dock** → Sound activates and follows finger
- **Release** → Sound stays at that position/volume
- **Pull higher** → Volume increases
- **Pull lower** → Volume decreases
- **Pull to dock** → Sound deactivates (returns to dock)

### Rule 2: Tap to Quick Adjust
- **Tap active orb** → Quick volume boost (temporary)
- **Double tap** → Toggle mute/unmute
- **Long press** → Show preset options

### Rule 3: Central Hub
- **Always visible** at center-top
- **Tap** → Play/pause all sounds
- **Shows blended color** of all active sounds
- **Rotates** when playing

### Rule 4: Sound Dock
- **Bottom 10% of screen** = Dock area
- **Horizontal scroll** to see all sounds
- **Drag from dock** to activate
- **Drag to dock** to deactivate
- **Shows all available sounds** (even inactive ones)

### Rule 5: Multiple Sounds
- **No limit** on active sounds
- **Sounds can overlap** visually (z-ordering by activation time)
- **Particles blend** when sounds are close
- **Colors blend** in background

---

## 🎨 Visual Feedback Rules

### 1. Volume Indicators
- **Height** = Primary volume indicator
- **Orb size** = Secondary indicator (scales with volume)
- **Particle density** = Tertiary indicator
- **Glow intensity** = Volume intensity
- **Percentage text** = Precise value

### 2. Spatial Feedback
- **Position** = Visual indicator of panning
- **Distance from center** = Depth indicator
- **Orb opacity** = Distance from center (farther = more transparent)

### 3. Active State Feedback
- **Pulsing glow** = Sound is active
- **Particle trails** = Sound is playing
- **Waveform rings** = Audio is active
- **Color intensity** = Volume level

---

## 🚨 Edge Cases & Solutions

### Edge Case 1: Multiple Sounds at Same Position
**Solution**: 
- Slight offset on release (spiral arrangement)
- Z-ordering by activation time (newest on top)
- Particles blend colors

### Edge Case 2: Pulling Too Fast
**Solution**:
- Spring animation to catch up
- Smooth interpolation
- Haptic feedback at volume milestones

### Edge Case 3: Accidental Deactivation
**Solution**:
- Dock has a "dead zone" (bottom 5%)
- Requires deliberate drag into dock
- Confirmation haptic when entering dock

### Edge Case 4: Screen Rotation
**Solution**:
- Maintain relative positions
- Recalculate dock position
- Smooth transition animation

### Edge Case 5: Too Many Active Sounds
**Solution**:
- Visual grouping (clustered sounds)
- Auto-arrange option
- "Clear all" gesture (swipe down from top)

### Edge Case 6: Preset Application
**Solution**:
- Long press central hub → Show presets
- Apply preset → Animate sounds to positions
- Smooth transition with spring animations

### Edge Case 7: Master Volume Control
**Solution**:
- Pinch central hub → Adjust master volume
- Visual feedback on all orbs
- All sounds scale proportionally

### Edge Case 8: Sound Library
**Solution**:
- Swipe up from dock → Show all sounds
- Drag new sounds from library
- Library auto-dismisses after selection

---

## 🎯 User Flow

### First Time User:
1. See dock with available sounds at bottom
2. See central hub at top
3. Pull a sound up → See it activate
4. Pull higher → Volume increases
5. Release → Sound stays active
6. Pull another sound → Multiple sounds blend

### Power User:
1. Quick drag multiple sounds up
2. Position for spatial audio
3. Fine-tune with tap gestures
4. Use presets for quick setups
5. Master volume control via hub

---

## ✨ Delightful Details

1. **Haptic Feedback**:
   - Light tap: Volume milestone (every 25%)
   - Medium tap: Sound activation
   - Heavy tap: Master play/pause

2. **Smooth Animations**:
   - Spring physics for all movements
   - Ease-in-out for volume changes
   - Particle physics for trails

3. **Visual Polish**:
   - Orb shadows follow position
   - Particles fade naturally
   - Colors blend smoothly
   - Glow pulses with audio

4. **Sound Design** (Future):
   - Subtle whoosh when activating
   - Click when reaching milestones
   - Ambient sound when idle

---

## 📱 Screen Layout

```
┌─────────────────────────┐
│   [Central Hub]         │ ← Top 15%
│   (Play/Pause)          │
│                         │
│                         │
│   [Active Sounds]       │ ← Middle 75%
│   (Floating Orbs)       │
│                         │
│                         │
│                         │
├─────────────────────────┤
│ [Sound Dock]            │ ← Bottom 10%
│ [🔵] [🟢] [🟠] [🟣]... │
└─────────────────────────┘
```

---

## 🎨 Color & Visual Hierarchy

1. **Docked sounds**: 30% opacity, small
2. **Active sounds**: 100% opacity, full size
3. **Central hub**: Always prominent, glowing
4. **Background**: Dark, adapts to active sounds
5. **Particles**: Match sound color, fade over time

---

This UX system creates an **intuitive, delightful, and powerful** interface that feels natural and magical! 🚀

