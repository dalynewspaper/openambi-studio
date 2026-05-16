import SwiftUI

/// Editorial section container for the Atelier (Phase 4.3).
///
/// Replaces `SettingsGroup`. The v1 group was a white rounded
/// rectangle with a 0.5pt black-opacity hairline — pure iOS Settings.
/// `AtelierSection` is the openambi 2.0 equivalent: an Aurora glass
/// surface with an editorial caption above (kicker + optional
/// description), 1pt Aurora hairline border, and 1pt
/// AuroraColors.Stroke.hairline dividers between rows.
///
///     ATELIER · LISTENING
///     How the room behaves while playing.
///     ┌───────────────────────────────┐
///     │ row 1                         │
///     ├───────────────────────────────┤
///     │ row 2                         │
///     └───────────────────────────────┘
///
/// The kicker uses the same vocabulary as every other room header in
/// the app, so the Atelier reads as a series of small rooms rather
/// than a settings checklist.
struct AtelierSection<Content: View>: View {

    /// The kicker line — short, all caps, kerning 2.4. Pass nil to
    /// render a section with no title (for the colophon at the
    /// bottom of the Atelier).
    let title: String?

    /// One-line description rendered below the kicker. Optional.
    let caption: String?

    @ViewBuilder let content: Content

    init(
        _ title: String? = nil,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AuroraTypography.editorial(11, weight: .medium))
                        .kerning(2.4)
                        .textCase(.uppercase)
                        .foregroundColor(AuroraColors.TextOnAurora.tertiary)

                    if let caption {
                        Text(caption)
                            .font(AuroraTypography.editorial(13, weight: .regular))
                            .foregroundColor(AuroraColors.TextOnAurora.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 4)
            }

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity)
            .background(borderOverlay)
            .auroraGlass(.surface, cornerRadius: 18)
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
    }
}

/// Single editorial row inside an `AtelierSection` (Phase 4.3).
///
/// Replaces `SettingsRow`. Differences from v1:
/// - SF Symbol sits in a transparent capsule with an
///   AuroraColors.Stroke.edge hairline rather than a colored
///   rounded-square. Color is the dominant sound color (or a
///   passed-in tint), so icons follow the active mix instead of
///   competing with it.
/// - Title in AuroraTypography.editorial(15, .medium) and subtitle
///   in editorial(12, .regular) tertiary — replaces the iOS
///   17pt/15pt body/secondary pair.
/// - Hairline divider between rows is rendered by the parent
///   AtelierSection, not by a `showDivider` flag on the row.
struct AtelierRow<Trailing: View>: View {

    let icon: String
    let title: String
    let subtitle: String?

    @ViewBuilder let trailing: Trailing

    /// Whether to render a 1pt hairline divider above this row.
    /// The first row in a section should set this to false.
    var showsDividerAbove: Bool = true

    @Environment(\.dominantSoundColor) private var dominant

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        showsDividerAbove: Bool = true,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showsDividerAbove = showsDividerAbove
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDividerAbove {
                Rectangle()
                    .fill(AuroraColors.Stroke.hairline)
                    .frame(height: 1)
            }

            HStack(spacing: AppSpacing.md) {
                iconChip
                textColumn
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
        }
    }

    private var iconChip: some View {
        ZStack {
            Circle()
                .fill(dominant.opacity(0.10))
            Circle()
                .strokeBorder(AuroraColors.Stroke.edge, lineWidth: 0.75)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AuroraColors.IconOnAurora.active)
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AuroraTypography.editorial(15, weight: .medium))
                .foregroundColor(AuroraColors.TextOnAurora.primary)

            if let subtitle {
                Text(subtitle)
                    .font(AuroraTypography.editorial(12, weight: .regular))
                    .foregroundColor(AuroraColors.TextOnAurora.tertiary)
            }
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 24) {
                AtelierSection("Atelier · Listening", caption: "How the room behaves while playing.") {
                    AtelierRow(icon: "waveform", title: "Fade In Duration", subtitle: "1 second", showsDividerAbove: false) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(AuroraColors.IconOnAurora.inactive)
                            .font(.system(size: 13, weight: .medium))
                    }
                    AtelierRow(icon: "lock.fill", title: "Background Playback", subtitle: "Play while screen is locked") {
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                }
                AtelierSection {
                    AtelierRow(icon: "info.circle", title: "Version", subtitle: "1.0", showsDividerAbove: false) {
                        EmptyView()
                    }
                }
            }
            .padding(20)
        }
    }
    .environment(\.dominantSoundColor, SoundColor.rain)
}
#endif
