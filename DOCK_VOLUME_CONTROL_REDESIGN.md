# Dock Volume Control Redesign Plan

## Problem Analysis

### Root Cause
SwiftUI `ScrollView` clips its content by default. Elements inside a `ScrollView` **cannot** escape its bounds, regardless of:
- zIndex values
- Full-screen containers
- Frame modifiers
- Offset values

When a `DockSoundChip` moves up (negative `dragOffset`), it gets clipped at the `ScrollView`'s top boundary, causing elements to disappear.

### Current Architecture Issues
1. **ScrollView Clipping**: All elements are rendered inside a `ScrollView(.horizontal)`, which clips vertically
2. **No Position Tracking**: We don't track where elements are positioned in the dock
3. **Single Rendering Context**: Elements are only rendered in one place (inside ScrollView)
4. **No Escape Mechanism**: Once in ScrollView, elements can't move outside its bounds

## Solution Architecture

### Core Strategy: Dual Rendering with Position Tracking

1. **Normal State**: Elements render inside ScrollView (for horizontal scrolling)
2. **Volume Mode**: Elements render in a full-screen overlay (outside ScrollView)
3. **Position Tracking**: Use PreferenceKey to track dock element positions
4. **Smooth Transition**: Animate between dock position and overlay position

### Implementation Plan

#### Phase 1: Position Tracking System
- Create `DockElementPositionPreferenceKey` to track element positions
- Each `DockSoundChip` reports its position in the dock
- Store positions in `@State` dictionary: `[UUID: CGPoint]`

#### Phase 2: Dual Rendering Architecture
- **Dock View**: Render non-volume-mode elements in ScrollView
- **Overlay View**: Render volume-mode elements in full-screen ZStack overlay
- Overlay positioned at top of ZStack hierarchy (highest zIndex)

#### Phase 3: Position Synchronization
- When entering volume mode:
  - Capture current dock position
  - Render element in overlay at same position
  - Hide element in dock (opacity: 0, but keep for layout)
- When dragging:
  - Update overlay element position based on dragOffset
  - Element moves freely in overlay (no clipping)
- When exiting volume mode:
  - Animate element back to dock position
  - Show element in dock, hide in overlay

#### Phase 4: Gesture Handling
- Gestures attached to overlay elements (not dock elements)
- Overlay elements handle all volume control interactions
- Dock elements only handle tap (toggle on/off)

## Technical Implementation

### New Components

1. **DockElementPositionPreferenceKey**
   ```swift
   struct DockElementPositionPreferenceKey: PreferenceKey {
       static var defaultValue: [UUID: CGPoint] = [:]
       static func reduce(value: inout [UUID: CGPoint], nextValue: () -> [UUID: CGPoint]) {
           value.merge(nextValue(), uniquingKeysWith: { $1 })
       }
   }
   ```

2. **ActiveMixDock (Redesigned)**
   - Two rendering contexts:
     - ScrollView for dock (normal state)
     - ZStack overlay for volume mode
   - Position tracking via PreferenceKey
   - State management for volume mode elements

3. **DockSoundChip (Enhanced)**
   - Reports position via PreferenceKey
   - Can render in two contexts (dock vs overlay)
   - Gesture handling for volume control

### Key Changes

1. **ActiveMixDock Structure**:
   ```swift
   ZStack {
       // Full-screen overlay for volume-mode elements
       ForEach(volumeModeElements) { element in
           element.overlayView(at: trackedPosition)
       }
       
       // Dock ScrollView for normal elements
       ScrollView {
           ForEach(normalElements) { element in
               element.dockView()
                   .preference(key: DockElementPositionPreferenceKey.self, ...)
           }
       }
   }
   ```

2. **Position Tracking**:
   - Use `GeometryReader` + `preference(key:value:)` to track positions
   - Store in `@State private var dockPositions: [UUID: CGPoint] = [:]`
   - Update on layout changes

3. **Volume Mode Transition**:
   - Enter: Capture position → Render in overlay → Hide in dock
   - Drag: Update overlay position (no constraints)
   - Exit: Animate to dock position → Show in dock → Remove from overlay

## Benefits

1. **No Clipping**: Overlay elements are outside ScrollView bounds
2. **Full Movement**: Elements can move anywhere on screen
3. **Smooth UX**: Position tracking ensures seamless transitions
4. **Maintainable**: Clear separation of concerns
5. **Performant**: Only volume-mode elements rendered in overlay

## Implementation Steps

1. ✅ Create PreferenceKey for position tracking
2. ✅ Add position tracking to DockSoundChip
3. ✅ Refactor ActiveMixDock with dual rendering
4. ✅ Implement overlay rendering for volume mode
5. ✅ Add position synchronization logic
6. ✅ Test volume control at all ranges (0-100%)
7. ✅ Ensure smooth transitions
8. ✅ Verify no clipping issues

## Testing Checklist

- [ ] Element visible at 0% (dock position)
- [ ] Element visible at 50% (mid-screen)
- [ ] Element visible at 100% (top of screen)
- [ ] Smooth transition entering volume mode
- [ ] Smooth transition exiting volume mode
- [ ] No clipping at any volume level
- [ ] Percentage label always visible
- [ ] Multiple elements can be in volume mode
- [ ] Horizontal scrolling works when not in volume mode
- [ ] Gestures work correctly in overlay

