import SwiftUI

/// The three top-level "rooms" of openambi 2.0.
///
/// Each room owns a coherent set of intentions:
/// - **Field**   — capture sounds; browse the library of places you've made.
/// - **Studio**  — live mix and immersive scene (default home).
/// - **Atelier** — identity, settings, appearance, the personal cabinet.
///
/// `rawValue` is stable across releases; treat it as the persisted
/// "last selected tab" key. The TabView in `ContentView` still uses the
/// Int rawValue for selection so children that read `Binding<Int>` don't
/// need to be refactored.
enum Room: Int, CaseIterable, Identifiable {
    case field = 0
    case studio = 1
    case atelier = 2

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .field:   return "Field"
        case .studio:  return "Studio"
        case .atelier: return "Atelier"
        }
    }

    /// A short, italic-leaning subtitle used in onboarding and the page
    /// rail's room-name reveal. Single sentence, lowercase, no period.
    var subtitle: String {
        switch self {
        case .field:   return "capture and collect"
        case .studio:  return "live mix"
        case .atelier: return "your studio"
        }
    }

    /// SF Symbol fallback for places that need a glyph (rail accessibility,
    /// onboarding, future Atelier shortcuts).
    var systemSymbol: String {
        switch self {
        case .field:   return "mic.fill"
        case .studio:  return "circle.dotted"
        case .atelier: return "person.crop.circle"
        }
    }

    init?(tabIndex: Int) {
        self.init(rawValue: tabIndex)
    }
}
