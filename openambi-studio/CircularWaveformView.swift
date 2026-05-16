import SwiftUI

/// Circular audio visualization for the Field room's capture orb.
///
/// The v1 capture screen used a horizontal `LevelMeterView` — 30 bars that
/// rose and fell with the mic input. It was clear, but flat. openambi 2.0
/// asks the capture screen to feel like an instrument; the orb should look
/// like the room itself is breathing through it.
///
/// This view draws `barCount` capsule bars radiating outward from a central
/// negative space. Each bar's length is driven by the recording level
/// modulated by a per-bar phase, animated by a `TimelineView` so the wave
/// stays alive even when the level is steady. The center is empty — by
/// design — so the parent can place the record button inside it.
///
/// Visual states:
/// - **Idle**: bars are short, low opacity. Suggests "I'm listening".
/// - **Recording**: bars expand, opacity rises, tint shifts toward the
///   recording color. The orb breathes with the room.
/// - **Reduce Motion**: TimelineView is bypassed; bars use the raw level
///   only, no phase shift. The visualization is calmer.
struct CircularWaveformView: View {

    /// 0…1 — the live audio level from `RecordingManager.audioLevel`.
    let level: Double

    var isRecording: Bool = false
    var diameter: CGFloat = 260
    var innerRadius: CGFloat = 100
    var barCount: Int = 64
    var minBarLength: CGFloat = 6
    var maxBarLength: CGFloat = 56
    var idleTint: Color = .white.opacity(0.55)
    var recordingTint: Color = Color(red: 1.0, green: 0.38, blue: 0.42)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.12 : 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let centerX = size.width / 2
                let centerY = size.height / 2
                let smoothedLevel = max(0.04, level)

                for i in 0..<barCount {
                    let normIndex = Double(i) / Double(barCount)
                    // Per-bar phase makes neighbours offset; the global
                    // time term `t` makes the wave ripple around the ring.
                    let phase = normIndex * .pi * 4 + (reduceMotion ? 0 : t * 1.8)
                    let variance = (sin(phase) * 0.32 + 0.78)
                    let raw = smoothedLevel * variance
                    let normalized = max(0.0, min(1.0, raw))
                    let length = minBarLength + (maxBarLength - minBarLength) * CGFloat(normalized)

                    let angle = normIndex * .pi * 2 - .pi / 2
                    let cosA = cos(angle)
                    let sinA = sin(angle)

                    let r1 = innerRadius
                    let r2 = innerRadius + length
                    let p1 = CGPoint(x: centerX + CGFloat(cosA) * r1,
                                     y: centerY + CGFloat(sinA) * r1)
                    let p2 = CGPoint(x: centerX + CGFloat(cosA) * r2,
                                     y: centerY + CGFloat(sinA) * r2)

                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)

                    let tint = barColor(progress: normalized)
                    ctx.stroke(path,
                               with: .color(tint),
                               style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                }
            }
            .frame(width: diameter, height: diameter)
        }
        .accessibilityElement()
        .accessibilityLabel(isRecording ? "Recording audio meter" : "Microphone meter")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    /// Color stops based on the bar's normalized length. Quieter bars
    /// stay muted; the louder a bar gets, the more it picks up the
    /// recording tint. Idle states fade toward white.
    private func barColor(progress: Double) -> Color {
        let base = isRecording ? recordingTint : idleTint
        if !isRecording {
            return base.opacity(0.35 + progress * 0.45)
        }
        if progress > 0.85 {
            return Color(red: 1.0, green: 0.78, blue: 0.42)
        } else if progress > 0.65 {
            return base
        } else {
            return base.opacity(0.45 + progress * 0.35)
        }
    }
}

#if DEBUG
private struct WavePreviewHost: View {
    @State private var level: Double = 0.3
    @State private var recording: Bool = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 32) {
                CircularWaveformView(level: level, isRecording: recording)

                Slider(value: $level, in: 0...1)
                    .padding(.horizontal, 40)
                    .tint(.white)

                Toggle("Recording", isOn: $recording)
                    .padding(.horizontal, 40)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    WavePreviewHost()
}
#endif
