# Focus Mode UX Enhancement Brief

## Overview
Transform OpenAmbi Studio into a truly immersive ambient sound experience by introducing a "Focus Mode" that minimizes visual distractions when sounds are active, allowing users to fully immerse themselves in the audio environment.

## Core Concept
When audio tracks are active, the sound element grid gracefully fades away, leaving only the beautiful, slow-moving background color animations. Users can tap anywhere to re-engage with the sound controls when needed.

---

## User Experience Flow

### 1. **Initial State (No Active Sounds)**
- Full grid of sound elements visible
- Background animations subtle and minimal
- Clear visual hierarchy with all options available

### 2. **Activation Transition (Sound Turned On)**
When a user taps a sound element to activate it:

**Phase 1: Selection Animation (0.3s)**
- Selected sound element scales up slightly (1.1x) with gentle spring animation
- Subtle glow pulse around the selected element
- Haptic feedback (light impact)

**Phase 2: Grid Reordering (0.5s)**
- Active sound smoothly animates to top-left position
- Uses spring animation with slight overshoot for natural feel
- Other inactive sounds shift down to fill the space
- Grid maintains 3-column layout throughout transition

**Phase 3: Focus Mode Entry (1.0s)**
- After active sound reaches top position, begin fade-out sequence
- All sound elements fade to 0% opacity over 1 second
- Background color animations intensify slightly (opacity increase from 0.08 to 0.15)
- Smooth, elegant transition using easeInOut curve

### 3. **Focus Mode (Active Sounds Playing)**
- Grid completely hidden (opacity: 0)
- Only background color animations visible
- Animations respond to active sounds' colors and volumes
- Clean, distraction-free visual experience
- Subtle visual feedback that audio is playing (gentle color washes)

### 4. **Re-engagement (Tap to Return)**
- Single tap anywhere on screen brings grid back
- Grid fades in over 0.6s with easeOut curve
- Active sounds remain at top, clearly visible
- Background animations return to subtle state
- Haptic feedback (light impact) on tap

### 5. **Deactivation (Sound Turned Off)**
- If last active sound is turned off:
  - Grid immediately fades back in (0.4s)
  - Sound element returns to original position in grid
  - Background animations return to minimal state

---

## Technical Specifications

### Animation Timings
- **Selection Animation**: 0.3s (spring, damping: 0.7, response: 0.4)
- **Grid Reordering**: 0.5s (spring, damping: 0.8, response: 0.5)
- **Focus Mode Entry**: 1.0s (easeInOut)
- **Grid Fade-In**: 0.6s (easeOut)
- **Grid Fade-Out on Deactivation**: 0.4s (easeIn)

### Visual States

#### Active Sound Element (in Focus Mode)
- Position: Top-left of grid (first position)
- Scale: 1.0 (normal size)
- Opacity: 0 (hidden during focus mode)
- When grid returns: Fully visible, slightly larger glow

#### Background Animations
- **Inactive State**: Opacity 0.08, slow movement
- **Focus Mode**: Opacity 0.15, slightly more prominent
- **Color Intensity**: Scales with active track volume (0.08 to 0.2)

### Interaction States

#### Tap Detection
- **Focus Mode Active**: Single tap anywhere → Show grid
- **Grid Visible**: Normal interactions (tap to toggle, long-press for volume)
- **Tap Outside Grid**: If grid is visible and user taps empty space → Enter focus mode

---

## Edge Cases & Considerations

### Multiple Active Sounds
- All active sounds move to top of grid (maintaining order)
- When entering focus mode, all fade out together
- When grid returns, all active sounds visible at top

### Volume Adjustment
- Long-press on active sound in grid → Enter volume mode
- Volume mode temporarily shows grid (even in focus mode)
- After volume adjustment, can return to focus mode

### Quick Toggle
- If user quickly toggles sound on/off:
  - Don't enter focus mode for very brief activations (< 2 seconds)
  - Only enter focus mode if sound remains active for 2+ seconds

### Accessibility
- VoiceOver: Announce "Focus mode active" when grid fades
- VoiceOver: Announce "Grid visible" when grid returns
- Maintain all accessibility features in both states

---

## Visual Polish

### Transition Effects
- **Fade**: Smooth opacity transitions, no harsh cuts
- **Scale**: Subtle scale animations for selection feedback
- **Position**: Smooth spring-based movement for reordering
- **Color**: Gradual color intensity changes in background

### Haptic Feedback
- **Sound Activated**: Light impact
- **Focus Mode Entered**: Medium impact
- **Grid Returned**: Light impact
- **Sound Deactivated**: Light impact

### Performance
- Use `drawingGroup()` for complex views during transitions
- Throttle background animation updates during transitions
- Ensure 60fps throughout all animations

---

## Implementation Phases

### Phase 1: Core Functionality
1. Implement grid fade-out when sounds are active
2. Add tap-to-return functionality
3. Basic reordering animation

### Phase 2: Polish
1. Smooth spring animations for reordering
2. Background animation intensity changes
3. Haptic feedback integration

### Phase 3: Edge Cases
1. Multiple active sounds handling
2. Quick toggle detection
3. Volume mode integration

### Phase 4: Accessibility & Testing
1. VoiceOver support
2. Performance optimization
3. User testing and refinement

---

## Success Metrics
- **Immersiveness**: Users report feeling more focused/relaxed
- **Usability**: Users can easily toggle between focus and control modes
- **Performance**: All animations run at 60fps
- **Accessibility**: Full VoiceOver support maintained

---

## Design Principles
1. **Minimal Distraction**: Focus mode should be truly minimal
2. **Easy Return**: Grid should return instantly on tap
3. **Visual Continuity**: Transitions should feel natural and fluid
4. **User Control**: User always has control over when to see/hide grid
5. **Elegant Simplicity**: Less is more - let the audio and colors shine

---

## Next Steps
1. Review and approve this brief
2. Implement Phase 1 (core functionality)
3. User testing with focus mode
4. Iterate based on feedback
5. Complete remaining phases

