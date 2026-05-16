import SwiftUI

/// Identity hero band at the top of the Atelier (Phase 4.2).
///
/// Replaces the v1 `SettingsProfileCard` (a near-clone of the iOS
/// Settings account row — small avatar, blue chevron, white card on
/// grey). The new band reads as a portrait moment: a generous 96pt
/// avatar over Aurora editorial typography on the same Aurora glass
/// surface as the rest of the IA.
///
/// Two modes:
/// - signed in:    shows the user's photo or a palette-derived
///                 initial avatar, friendly name, and a meaningful
///                 caption ('Member since June 2025' or
///                 'Signed in with Apple').
/// - signed out:   shows a calm invitation to sign in. The whole
///                 card becomes the affordance — a small but
///                 unmistakable "make this room yours" gesture.
struct AtelierIdentity: View {

    let user: User?
    let onTapSignedIn: () -> Void
    let onTapSignedOut: () -> Void

    @Environment(\.dominantSoundColor) private var dominant

    var body: some View {
        Button(action: tapHandler) {
            cardContent
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity)
                .background(borderOverlay)
                .auroraGlass(.surface, cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(user == nil ? "Sign in to sync your mixes." : "Open profile.")
    }

    @ViewBuilder
    private var cardContent: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            avatar
                .frame(width: 64, height: 64)
            textColumn
            Spacer(minLength: 8)
            chevron
        }
    }

    @ViewBuilder
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleText)
                .font(AuroraTypography.editorial(20, weight: .semibold))
                .foregroundColor(AuroraColors.TextOnAurora.primary)
                .lineLimit(1)

            Text(subtitleText)
                .font(AuroraTypography.editorial(13, weight: .regular))
                .foregroundColor(AuroraColors.TextOnAurora.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var chevron: some View {
        Image(systemName: user == nil ? "arrow.right.circle" : "chevron.right")
            .font(.system(size: user == nil ? 22 : 14, weight: .medium))
            .foregroundColor(AuroraColors.IconOnAurora.inactive)
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatar: some View {
        if let user, let photoURL = user.photoURL, let url = URL(string: photoURL) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialAvatar(letter: String(user.friendlyName.prefix(1)).uppercased())
            }
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
            )
        } else if let user {
            initialAvatar(letter: String(user.friendlyName.prefix(1)).uppercased())
        } else {
            // Signed-out: an invitation, not a face. We use the brand
            // sigil here so the empty state still looks like the brand
            // saying hello rather than 'no user'.
            BrandRing(tint: dominant)
                .padding(8)
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle().strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
                )
        }
    }

    /// Palette-derived initial avatar — same vocabulary as a LibraryCard
    /// thumbnail, so the user's identity is rendered with the same
    /// language as their recordings.
    private func initialAvatar(letter: String) -> some View {
        let palette = LinearGradient(
            colors: [dominant.opacity(0.85), dominant.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return Circle()
            .fill(palette)
            .overlay(
                Text(letter)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            )
            .overlay(
                Circle().strokeBorder(AuroraColors.Stroke.edge, lineWidth: 1)
            )
    }

    // MARK: - Copy

    private var titleText: String {
        user?.friendlyName ?? "Make this room yours"
    }

    /// Editorial caption rather than literal account metadata.
    /// - signed in with createdAt:  'Member since June 2025'
    /// - signed in without:         user's email or 'Signed in with Apple'
    /// - signed out:                an invitation to start
    private var subtitleText: String {
        guard let user else {
            return "Sign in to sync your mixes, save what you record, and pick up the same scene on every device."
        }
        if let createdAt = user.createdAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return "Member since \(formatter.string(from: createdAt))"
        }
        return user.email ?? "Signed in with Apple"
    }

    private var accessibilityLabel: String {
        if let user {
            return "Profile. \(user.friendlyName). \(subtitleText)."
        }
        return "Sign in. Make this room yours."
    }

    private func tapHandler() {
        InstrumentFeedback.tap()
        if user == nil {
            onTapSignedOut()
        } else {
            onTapSignedIn()
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        VStack(spacing: 28) {
            AtelierIdentity(
                user: nil,
                onTapSignedIn: {},
                onTapSignedOut: {}
            )

            AtelierIdentity(
                user: User(
                    id: UUID(),
                    email: "brian@example.com",
                    fullName: "Brian Daly",
                    displayName: "Brian",
                    photoURL: nil,
                    createdAt: Date()
                ),
                onTapSignedIn: {},
                onTapSignedOut: {}
            )
        }
        .padding(20)
    }
    .environment(\.dominantSoundColor, SoundColor.rain)
}
#endif
