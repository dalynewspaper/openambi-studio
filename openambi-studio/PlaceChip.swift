import SwiftUI

/// Compact "you are here" badge for the Field room.
///
/// Renders as a single line of editorial text on an Aurora glass pill:
/// `Lisbon · 14:42 · sea breeze 12°C`
///
/// Behavior:
/// - Updates the time once a minute via a `TimelineView`.
/// - Place + weather come from `PlaceObserver.shared`; the chip animates
///   their appearance.
/// - Degrades gracefully:
///   - No place yet, no permission: shows only the time.
///   - No weather (network down, missing entitlement): shows place + time.
///   - Permission denied: shows time only, with a quiet tap-to-enable
///     affordance if the user taps it.
/// - Tapping the chip when permission isn't determined prompts for it;
///   tapping when granted refreshes manually.
struct PlaceChip: View {

    @StateObject private var observer = PlaceObserver.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
        .onAppear { observer.start() }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AuroraColors.IconOnAurora.inactive)
                    .opacity(observer.place == nil ? 0.55 : 0.9)

                Text(captionParts(now: now).joined(separator: "  ·  "))
                    .font(AuroraTypography.editorial(13, weight: .medium))
                    .foregroundColor(AuroraColors.TextOnAurora.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityLabel(accessibilitySummary(now: now))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.65)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(Motion.touch, value: observer.place)
    }

    // MARK: - Composition

    /// The visible string parts. Always includes time; includes place and
    /// weather descriptor when available.
    private func captionParts(now: Date) -> [String] {
        var parts: [String] = []
        if let locality = observer.place?.locality, !locality.isEmpty {
            parts.append(locality)
        }
        parts.append(timeFormatter.string(from: now))
        if let weather = observer.place?.weather {
            parts.append(weather.descriptor)
        }
        return parts
    }

    private func accessibilitySummary(now: Date) -> String {
        var elements: [String] = []
        if let locality = observer.place?.locality {
            elements.append("In \(locality)")
        }
        elements.append("Local time \(timeFormatter.string(from: now))")
        if let weather = observer.place?.weather {
            elements.append("Weather \(weather.descriptor)")
        }
        return elements.joined(separator: ", ")
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    // MARK: - Interaction

    private func handleTap() {
        InstrumentFeedback.tap()
        switch observer.authorizationStatus {
        case .notDetermined:
            observer.start() // triggers system prompt
        case .authorizedWhenInUse, .authorizedAlways:
            observer.start() // refresh
        default:
            break
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        PlaceChip()
    }
}
#endif
