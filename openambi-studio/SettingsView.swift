import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showSignIn = false
    @State private var showAccountDetails = false
    @State private var showDeleteAccount = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showAcknowledgements = false
    // The "My Recordings" entry was removed in openambi 2.0; the library
    // now lives in the Field room (see RecordingsLibrarySection). The
    // sheet binding below is intentionally retired.
    @State private var showProfileEdit = false
    
    var body: some View {
        ZStack {
            // Atelier scene background (Phase 4.1) — matches the rest of
            // the IA. The v1 used a clone of the iOS Settings sheet
            // background (light grey #F2F2F7) which broke the brand
            // entirely as soon as you swiped over here from the Studio.
            // The new background is the same AppTheme.background as the
            // Studio, with the rain-tinted DynamicLoadingBackground
            // wash for warmth and continuity.
            AppTheme.background
                .ignoresSafeArea(.all)
            DynamicLoadingBackground(trackName: "Rain")
                .opacity(0.55)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Editorial Atelier header sits where the iOS-
                        // grey 'Settings' title used to. Search was
                        // removed in 2.0 — the room is small enough to
                        // browse, and a search field would have been a
                        // tell that this is still iOS Settings under
                        // the hood.
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.top + AppSpacing.sm)

                        AtelierHeader(isAuthenticated: authManager.isAuthenticated)
                            .padding(.bottom, AppSpacing.lg)
                        
                        // Identity hero band (Phase 4.2). Replaces the
                        // v1 SettingsProfileCard. The signed-out variant
                        // is a calm invitation, not a throwaway 'Sign
                        // In' row — the whole card is the affordance.
                        AtelierIdentity(
                            user: authManager.isAuthenticated ? authManager.currentUser : nil,
                            onTapSignedIn: { showProfileEdit = true },
                            onTapSignedOut: { showSignIn = true }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                        
                        // Editorial section stack (Phase 4.3). The v1
                        // had six unnamed white SettingsGroups stacked
                        // generically; the new Atelier names each
                        // workspace and gives it a one-line caption so
                        // the user has a sense of what the room is
                        // actually about.
                        VStack(spacing: AppSpacing.lg) {
                            listeningSection
                            audioSection
                            preferencesSection
                            notificationsSection
                            librarySection
                            if authManager.isAuthenticated {
                                accountSection
                            }
                            aboutSection
                            colophon
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                }
            }
        }
        .sheet(isPresented: $showSignIn) {
            AuthenticationView(authManager: authManager)
        }
        .sheet(isPresented: $showAccountDetails) {
            AccountDetailsView(authManager: authManager)
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView(authManager: authManager)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showAcknowledgements) {
            AcknowledgementsView()
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView(authManager: authManager)
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // Close sign-in sheet when user successfully signs in
            if isAuthenticated {
                showSignIn = false
            }
        }
    }

    // MARK: - Editorial sections (Phase 4.3)

    /// 'How the room behaves while playing.' — fades + the lock-screen
    /// + the resume-last-mix preference. These are the toggles a user
    /// touches when they want to set the *temperament* of playback.
    private var listeningSection: some View {
        AtelierSection("Listening", caption: "How the room behaves while playing.") {
            AtelierRow(
                icon: "waveform",
                title: "Fade in duration",
                subtitle: FadeDuration(rawValue: settingsManager.fadeInDuration)?.displayName ?? "1 second",
                showsDividerAbove: false
            ) {
                rowChevron
            }
            AtelierRow(
                icon: "waveform.path",
                title: "Fade out on exit",
                subtitle: settingsManager.fadeOutOnExit ? "\(Int(settingsManager.fadeOutDuration)) seconds" : "Off"
            ) {
                Toggle("", isOn: $settingsManager.fadeOutOnExit).labelsHidden()
            }
            AtelierRow(
                icon: "lock.fill",
                title: "Background playback",
                subtitle: "Keep playing when the screen locks"
            ) {
                Toggle("", isOn: $settingsManager.backgroundPlayback).labelsHidden()
            }
            AtelierRow(
                icon: "arrow.clockwise",
                title: "Resume last mix",
                subtitle: settingsManager.resumeLastMix ? "On" : "Off"
            ) {
                Toggle("", isOn: $settingsManager.resumeLastMix).labelsHidden()
            }
        }
    }

    /// 'How loud, how dense.' — quality tiers for streaming and offline.
    private var audioSection: some View {
        AtelierSection("Audio", caption: "How loud, how dense.") {
            AtelierRow(
                icon: "music.note",
                title: "Streaming quality",
                subtitle: settingsManager.audioQuality.rawValue,
                showsDividerAbove: false
            ) { rowChevron }
            AtelierRow(
                icon: "arrow.down.circle",
                title: "Download quality",
                subtitle: settingsManager.downloadQuality.rawValue
            ) { rowChevron }
        }
    }

    /// 'How the room looks and feels.' — visual + sensory preferences.
    /// 'Atelier' as a section name would shadow the room itself, so
    /// this lives under 'Preferences' instead.
    private var preferencesSection: some View {
        AtelierSection("Preferences", caption: "How the room looks and feels.") {
            AtelierRow(
                icon: "paintbrush",
                title: "Theme",
                subtitle: settingsManager.theme.rawValue,
                showsDividerAbove: false
            ) { rowChevron }
            AtelierRow(
                icon: "sparkles",
                title: "Aurora glass",
                subtitle: settingsManager.liquidGlassEffects ? "On" : "Off"
            ) {
                Toggle("", isOn: $settingsManager.liquidGlassEffects).labelsHidden()
            }
            AtelierRow(
                icon: "figure.walk",
                title: "Reduce motion",
                subtitle: settingsManager.reduceMotion ? "On" : "Off"
            ) {
                Toggle("", isOn: $settingsManager.reduceMotion).labelsHidden()
            }
        }
    }

    /// 'When openambi can interrupt you.' — the calmer the better.
    private var notificationsSection: some View {
        AtelierSection("Notifications", caption: "When openambi can interrupt you.") {
            AtelierRow(
                icon: "bell",
                title: "New scenes",
                subtitle: settingsManager.notificationsNewScenes ? "On" : "Off",
                showsDividerAbove: false
            ) {
                Toggle("", isOn: $settingsManager.notificationsNewScenes).labelsHidden()
            }
            AtelierRow(
                icon: "calendar",
                title: "Daily mix suggestions",
                subtitle: settingsManager.notificationsDailyMix ? "On" : "Off"
            ) {
                Toggle("", isOn: $settingsManager.notificationsDailyMix).labelsHidden()
            }
            AtelierRow(
                icon: "heart",
                title: "Relaxation reminders",
                subtitle: settingsManager.notificationsRelaxation ? "On" : "Off"
            ) {
                Toggle("", isOn: $settingsManager.notificationsRelaxation).labelsHidden()
            }
        }
    }

    /// 'Where your sounds live.' — sync + storage hygiene.
    private var librarySection: some View {
        AtelierSection("Library", caption: "Where your sounds live.") {
            AtelierRow(
                icon: "icloud",
                title: "iCloud sync",
                subtitle: settingsManager.iCloudSync ? "On" : "Off",
                showsDividerAbove: false
            ) {
                Toggle("", isOn: $settingsManager.iCloudSync).labelsHidden()
            }
            Button(action: {
                InstrumentFeedback.tap()
                settingsManager.clearCachedAudio()
            }) {
                AtelierRow(
                    icon: "trash.circle",
                    title: "Clear cached audio",
                    subtitle: "Free up storage space"
                ) { rowChevron }
            }
            .buttonStyle(.plain)
        }
    }

    /// 'Account.' — billing + the deletion door. Sign-out lives here too,
    /// styled as a row rather than a hostile red button so it sits in
    /// the same vocabulary as the rest of the Atelier.
    private var accountSection: some View {
        AtelierSection("Account", caption: "Billing and the door out.") {
            Button(action: {
                InstrumentFeedback.tap()
            }) {
                AtelierRow(
                    icon: "creditcard",
                    title: "Manage subscription",
                    showsDividerAbove: false
                ) { rowChevron }
            }
            .buttonStyle(.plain)

            Button(action: {
                InstrumentFeedback.tap()
                Task { @MainActor in
                    await authManager.signOut()
                }
            }) {
                AtelierRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign out"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AuroraColors.IconOnAurora.inactive)
                }
            }
            .buttonStyle(.plain)

            Button(action: {
                InstrumentFeedback.tap()
                showDeleteAccount = true
            }) {
                AtelierRow(
                    icon: "trash",
                    title: "Delete account",
                    subtitle: "This cannot be undone"
                ) { rowChevron }
            }
            .buttonStyle(.plain)
        }
    }

    /// 'About.' — colophon, links, version. The brand colophon at the
    /// bottom (Phase 4.4) follows this section.
    private var aboutSection: some View {
        AtelierSection("About", caption: "Privacy, terms, and the credits.") {
            Button(action: {
                InstrumentFeedback.tap()
                showPrivacyPolicy = true
            }) {
                AtelierRow(
                    icon: "hand.raised",
                    title: "Privacy policy",
                    showsDividerAbove: false
                ) { rowChevron }
            }
            .buttonStyle(.plain)

            Button(action: {
                InstrumentFeedback.tap()
                showTermsOfService = true
            }) {
                AtelierRow(
                    icon: "doc.text",
                    title: "Terms of service"
                ) { rowChevron }
            }
            .buttonStyle(.plain)

            Button(action: {
                InstrumentFeedback.tap()
                showAcknowledgements = true
            }) {
                AtelierRow(
                    icon: "info.circle",
                    title: "Acknowledgements"
                ) { rowChevron }
            }
            .buttonStyle(.plain)

            AtelierRow(
                icon: "chart.bar",
                title: "Analytics & diagnostics",
                subtitle: settingsManager.analyticsEnabled ? "On" : "Off"
            ) {
                Toggle("", isOn: $settingsManager.analyticsEnabled).labelsHidden()
            }

            AtelierRow(
                icon: "number",
                title: "Version",
                subtitle: "1.0"
            ) {
                EmptyView()
            }
        }
    }

    private var rowChevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AuroraColors.IconOnAurora.inactive)
    }

    /// Brand colophon at the very bottom of the Atelier (Phase 4.4).
    ///
    /// The room ends like a book or magazine: a small mark, a version
    /// line, a quiet attribution. Centered, no chrome — just the
    /// BrandLockup at .display + a tertiary editorial caption with the
    /// app version and the design epoch.
    ///
    /// Functionally this also closes a UX gap from the v1 — the version
    /// number used to live mid-About list, formatted as if it were a
    /// settings row. Now it's where it belongs: as part of the colophon.
    private var colophon: some View {
        VStack(spacing: 12) {
            BrandLockup(layout: .vertical, size: .display, tint: AuroraColors.TextOnAurora.tertiary)

            Text("openambi 1.0 · openambi 2.0 design")
                .font(AuroraTypography.editorial(11, weight: .medium))
                .kerning(2.4)
                .textCase(.uppercase)
                .foregroundColor(AuroraColors.TextOnAurora.quaternary)
        }
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("openambi version 1.0, openambi 2.0 design")
    }
}

// MARK: - Account Details View
struct AccountDetailsView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if let user = authManager.currentUser {
                    Section {
                        if let email = user.email {
                            HStack {
                                Text("Email")
                                Spacer()
                                Text(email)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let fullName = user.fullName {
                            HStack {
                                Text("Name")
                                Spacer()
                                Text(fullName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Account Information")
                    }
                    
                    Section {
                        Button("Manage Subscription") {
                            // Open subscription management
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Delete Account View
struct DeleteAccountView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var confirmText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Delete Account")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 32)
                
                Text("This action cannot be undone. All your data, saved mixes, and preferences will be permanently deleted.")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                TextField("Type DELETE to confirm", text: $confirmText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 32)
                
                Button(action: {
                    // Delete account logic
                    dismiss()
                }) {
                    Text("Delete Account")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(confirmText == "DELETE" ? Color.red : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(confirmText != "DELETE")
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.bottom, 8)
                    
                    Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Text("Your privacy is important to us. This Privacy Policy explains how openambi collects, uses, and protects your information.")
                        .font(.system(size: 17))
                        .padding(.top, 8)
                    
                    // Add more privacy policy content here
                }
                .padding(24)
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Service")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.bottom, 8)
                    
                    Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Text("By using openambi, you agree to these Terms of Service.")
                        .font(.system(size: 17))
                        .padding(.top, 8)
                    
                    // Add more terms content here
                }
                .padding(24)
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Acknowledgements View
struct AcknowledgementsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Acknowledgements")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.bottom, 8)
                    
                    Text("openambi uses the following open-source libraries and frameworks:")
                        .font(.system(size: 17))
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        AcknowledgementRow(name: "SwiftUI", description: "Apple's declarative UI framework")
                        AcknowledgementRow(name: "AVFoundation", description: "Apple's audio framework")
                        AcknowledgementRow(name: "Supabase", description: "Backend and authentication")
                    }
                    .padding(.top, 16)
                }
                .padding(24)
            }
            .navigationTitle("Acknowledgements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AcknowledgementRow: View {
    let name: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 17, weight: .semibold))
            Text(description)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
    }
}

// SettingsProfileCard, SettingsGroup, and SettingsRow were removed
// in Phase 4.3 of openambi 2.0. Their roles are now played by:
//
//   - AtelierIdentity (replaces SettingsProfileCard)
//   - AtelierSection  (replaces SettingsGroup)
//   - AtelierRow      (replaces SettingsRow)
//
// All three live in the AtelierIdentity.swift / AtelierSection.swift
// files and use Aurora typography, AuroraGlass surfaces, and the
// dominantSoundColor environment, so the Atelier reads as part of the
// same brand surface as the Field and Studio.

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(AudioManager())
}
