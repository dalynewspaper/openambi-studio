import SwiftUI

/// The openambi wordmark, locked to Kode Mono with the brand kerning.
///
/// Use this view anywhere "openambi" appears as a brand element (splash, auth,
/// widgets, share cards). For body copy that happens to include the word
/// "openambi", continue to use system typography — this lockup is for moments,
/// not paragraphs.
struct Wordmark: View {
    enum Size {
        case widget   // 14pt — small widget, share card footer
        case caption  // 18pt — auth subtitle line, settings hero
        case display  // 28pt — section heroes
        case hero     // 40pt — splash, onboarding (matches SimpleLoadingView)

        var pointSize: CGFloat {
            switch self {
            case .widget: return 14
            case .caption: return 18
            case .display: return 28
            case .hero: return 40
            }
        }

        var kerning: CGFloat {
            switch self {
            case .widget: return 1.4
            case .caption: return 1.8
            case .display: return 2.2
            case .hero: return 2.5
            }
        }
    }

    var size: Size = .hero
    var tint: Color = .white
    /// Soft drop shadow for legibility over scene material. Disable for share
    /// cards / widgets where the background is already a contained surface.
    var hasShadow: Bool = true

    var body: some View {
        Text("openambi")
            .font(.custom("Kode Mono", size: size.pointSize))
            .foregroundColor(tint)
            .kerning(size.kerning)
            .shadow(color: hasShadow ? .black.opacity(0.3) : .clear,
                    radius: hasShadow ? 8 : 0,
                    x: 0,
                    y: hasShadow ? 2 : 0)
            .accessibilityLabel("openambi")
    }
}

/// Composite mark: the BrandRing sigil and the Wordmark stacked or inline.
struct BrandLockup: View {
    enum Layout { case vertical, horizontal }

    var layout: Layout = .vertical
    var size: Wordmark.Size = .hero
    var tint: Color = .white

    private var ringSide: CGFloat {
        // Ring tracks roughly 1.6x the wordmark cap height for an even visual weight.
        size.pointSize * 1.6
    }

    var body: some View {
        Group {
            switch layout {
            case .vertical:
                VStack(spacing: size.pointSize * 0.5) {
                    BrandRing(tint: tint)
                        .frame(width: ringSide, height: ringSide)
                    Wordmark(size: size, tint: tint)
                }
            case .horizontal:
                HStack(spacing: size.pointSize * 0.55) {
                    BrandRing(tint: tint, showsInnerGroove: ringSide >= 28)
                        .frame(width: ringSide, height: ringSide)
                    Wordmark(size: size, tint: tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("openambi")
    }
}

#Preview("Wordmark") {
    VStack(spacing: 28) {
        Wordmark(size: .hero)
        Wordmark(size: .display)
        Wordmark(size: .caption)
        Wordmark(size: .widget, hasShadow: false)
        Divider().background(Color.white.opacity(0.2))
        BrandLockup(layout: .vertical, size: .display)
        BrandLockup(layout: .horizontal, size: .caption)
    }
    .padding(40)
    .background(Color.black)
}
