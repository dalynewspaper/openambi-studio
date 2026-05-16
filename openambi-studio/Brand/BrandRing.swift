import SwiftUI

/// The openambi brand sigil: a thin concentric ring evocative of a vinyl groove,
/// a microphone diaphragm, and a planet seen edge-on.
///
/// Programmatic placeholder for the final designed PDF asset. Animatable via
/// `progress` (0...1) so the ring can draw on for the cinematic intro.
struct BrandRing: View {
    /// Draw progress from 0 (nothing) to 1 (complete circle). Defaults to a full ring.
    var progress: Double = 1.0
    /// Stroke width relative to the ring diameter. The default 1/24th matches the
    /// "1pt at 24pt" guideline so the sigil scales crisply from widget to hero.
    var strokeRatio: CGFloat = 1.0 / 24.0
    /// Ring color. Use `.white` over scene material; otherwise theme-aware.
    var tint: Color = .white
    /// Optional inner accent (the second concentric groove). Set ratio to 0 to hide.
    var innerRatio: CGFloat = 0.62
    /// Whether to render the inner groove. Hidden at small sizes (widget, in-line).
    var showsInnerGroove: Bool = true

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let stroke = max(0.5, side * strokeRatio)

            ZStack {
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                if showsInnerGroove && side >= 28 {
                    Circle()
                        .trim(from: 0, to: max(0, min(1, progress)))
                        .stroke(tint.opacity(0.45), style: StrokeStyle(lineWidth: stroke * 0.6, lineCap: .round))
                        .padding(side * (1 - innerRatio) / 2)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview("BrandRing — sizes") {
    VStack(spacing: 24) {
        BrandRing()
            .frame(width: 96, height: 96)
        BrandRing()
            .frame(width: 48, height: 48)
        BrandRing(showsInnerGroove: false)
            .frame(width: 24, height: 24)
        BrandRing(progress: 0.6, tint: Color(red: 0.3, green: 0.72, blue: 1.0))
            .frame(width: 96, height: 96)
    }
    .padding(40)
    .background(Color.black)
}
