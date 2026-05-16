import SwiftUI

/// Skeleton placeholder for `LibraryCard` used while the Field library
/// is loading from Supabase.
///
/// Instead of staring at a centered spinner, the user sees the *shape*
/// of the content forming: a stack of card silhouettes with a soft
/// chromatic shimmer sweeping across them. The brain registers this as
/// "the library is on its way" rather than "the app is stuck".
struct LibraryCardSkeleton: View {
    var body: some View {
        HStack(spacing: 18) {
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 14)
                    .frame(maxWidth: 180, alignment: .leading)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 11)
                    .frame(maxWidth: 110, alignment: .leading)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.55)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AuroraColors.Stroke.hairline, lineWidth: 1)
                )
        )
        .shimmer()
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                LibraryCardSkeleton()
            }
        }
        .padding(20)
    }
}
#endif
