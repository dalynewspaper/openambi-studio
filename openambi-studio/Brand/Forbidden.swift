// MARK: - Token-discipline guide (no runtime effect)
//
// This file documents patterns to avoid in new code during the
// openambi 2.0 redesign. It compiles to nothing — it exists so a
// reviewer can run `grep -n 'AVOID:' openambi-studio/Brand/Forbidden.swift`
// to see the rules in one place, and so that explanatory commits can
// reference a stable filename.
//
// All migrations from these patterns happen in Phase 2 alongside the
// screen redesigns (Field / Studio / Atelier). Phase 1 only lays the
// tokens down without forcing a global rewrite.
//
// AVOID: `Color.white.opacity(...)` as a text color.
//   USE:  AuroraColors.TextOnAurora.{primary, secondary, tertiary, quaternary}
//
// AVOID: `Color.white.opacity(...)` as a stroke/border.
//   USE:  AuroraColors.Stroke.{hairline, edge, focus}
//
// AVOID: `.font(.system(size: N))` or `.font(.system(size: N, weight: .X))`.
//   USE:  AuroraTypography.{editorial, display, ui, mono}(size, weight: ...)
//
// AVOID: Ad-hoc `.spring(response:dampingFraction:)` literals.
//   USE:  Motion.touch (interactive), Motion.cinema (scene-level),
//         Motion.breath (ambient loops).
//
// AVOID: Constructing `UIImpactFeedbackGenerator` / `UISelection…` /
//        `UINotificationFeedbackGenerator` inline.
//   USE:  InstrumentFeedback semantic intents (`.tap()`, `.toggle(...)`,
//         `.threshold(at:)`, `.preset(applied:)`, `.cinema()`, etc.).
//
// AVOID: Reading `ProcessInfo.processInfo.isLowPowerModeEnabled`
//        in views.
//   USE:  AmbientFeatureFlags.shared.<capability>.
//
// AVOID: A view that needs the current "dominant sound color" reading
//        from `audioManager.tracks` directly to pick a tint.
//   USE:  @Environment(\.dominantSoundColor); Soundscape3DView is the
//         single publisher (wired in Phase 3 when the Studio
//         constellation lands).
