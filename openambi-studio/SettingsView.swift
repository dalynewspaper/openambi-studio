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
                        
                        // Account Settings Group (if authenticated)
                        if authManager.isAuthenticated {
                            SettingsGroup {
                                // "My Recordings" intentionally removed in
                                // openambi 2.0 — the library now lives in
                                // the Field room (swipe right to open).
                                Button(action: {
                                    // Open subscription management
                                }) {
                                    SettingsRow(
                                        icon: "creditcard",
                                        iconColor: .blue,
                                        title: "Manage Subscription",
                                        showDivider: true,
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    showDeleteAccount = true
                                }) {
                                    SettingsRow(
                                        icon: "trash",
                                        iconColor: .red,
                                        title: "Delete Account",
                                        showDivider: false,
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
                        
                        // Playback Settings Group
                        SettingsGroup {
                            SettingsRow(
                                icon: "waveform",
                                iconColor: .blue,
                                title: "Fade In Duration",
                                subtitle: FadeDuration(rawValue: settingsManager.fadeInDuration)?.displayName ?? "1s",
                                showDivider: true,
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            )
                            
                            SettingsRow(
                                icon: "waveform.path",
                                iconColor: .blue,
                                title: "Fade Out on Exit",
                                subtitle: settingsManager.fadeOutOnExit ? "\(Int(settingsManager.fadeOutDuration))s" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.fadeOutOnExit)
                                        .labelsHidden()
                                }
                            )
                            
                            SettingsRow(
                                icon: "lock.fill",
                                iconColor: .green,
                                title: "Background Playback",
                                subtitle: "Play audio when screen is locked",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.backgroundPlayback)
                                        .labelsHidden()
                                }
                            )
                            
                            SettingsRow(
                                icon: "arrow.clockwise",
                                iconColor: .blue,
                                title: "Resume Last Mix",
                                subtitle: settingsManager.resumeLastMix ? "On" : "Off",
                                showDivider: false,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.resumeLastMix)
                                        .labelsHidden()
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        
                        // Audio Quality Settings Group
                        SettingsGroup {
                            SettingsRow(
                                icon: "music.note",
                                iconColor: .purple,
                                title: "Audio Quality",
                                subtitle: settingsManager.audioQuality.rawValue,
                                showDivider: true,
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            )
                            
                            SettingsRow(
                                icon: "arrow.down.circle",
                                iconColor: .blue,
                                title: "Download Quality",
                                subtitle: settingsManager.downloadQuality.rawValue,
                                showDivider: false,
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        
                        // Appearance Settings Group
                        SettingsGroup {
                            SettingsRow(
                                icon: "paintbrush",
                                iconColor: .gray,
                                title: "Theme",
                                subtitle: settingsManager.theme.rawValue,
                                showDivider: true,
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            )
                            
                            SettingsRow(
                                icon: "sparkles",
                                iconColor: .blue,
                                title: "Visual Effects",
                                subtitle: settingsManager.liquidGlassEffects ? "Liquid Glass On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.liquidGlassEffects)
                                        .labelsHidden()
                                }
                            )
                            
                            SettingsRow(
                                icon: "figure.walk",
                                iconColor: .blue,
                                title: "Reduce Motion",
                                subtitle: settingsManager.reduceMotion ? "On" : "Off",
                                showDivider: false,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.reduceMotion)
                                        .labelsHidden()
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        
                        // Notifications Settings Group
                        SettingsGroup {
                            SettingsRow(
                                icon: "bell",
                                iconColor: .orange,
                                title: "New Scenes",
                                subtitle: settingsManager.notificationsNewScenes ? "On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.notificationsNewScenes)
                                        .labelsHidden()
                                }
                            )
                            
                            SettingsRow(
                                icon: "calendar",
                                iconColor: .blue,
                                title: "Daily Mix Suggestions",
                                subtitle: settingsManager.notificationsDailyMix ? "On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.notificationsDailyMix)
                                        .labelsHidden()
                                }
                            )
                            
                            SettingsRow(
                                icon: "heart",
                                iconColor: .pink,
                                title: "Relaxation Reminders",
                                subtitle: settingsManager.notificationsRelaxation ? "On" : "Off",
                                showDivider: false,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.notificationsRelaxation)
                                        .labelsHidden()
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        
                        // Data & Sync Settings Group
                        SettingsGroup {
                            SettingsRow(
                                icon: "icloud",
                                iconColor: .blue,
                                title: "iCloud Sync",
                                subtitle: settingsManager.iCloudSync ? "On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.iCloudSync)
                                        .labelsHidden()
                                }
                            )
                            
                            Button(action: {
                                settingsManager.clearCachedAudio()
                            }) {
                                SettingsRow(
                                    icon: "trash.circle",
                                    iconColor: .orange,
                                    title: "Clear Cached Audio",
                                    subtitle: "Free up storage space",
                                    showDivider: false,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        
                        // About & Privacy Settings Group
                        SettingsGroup {
                            Button(action: {
                                showPrivacyPolicy = true
                            }) {
                                SettingsRow(
                                    icon: "hand.raised",
                                    iconColor: .blue,
                                    title: "Privacy Policy",
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                showTermsOfService = true
                            }) {
                                SettingsRow(
                                    icon: "doc.text",
                                    iconColor: .gray,
                                    title: "Terms of Service",
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                showAcknowledgements = true
                            }) {
                                SettingsRow(
                                    icon: "info.circle",
                                    iconColor: .blue,
                                    title: "Acknowledgements",
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            SettingsRow(
                                icon: "chart.bar",
                                iconColor: .gray,
                                title: "Analytics & Diagnostics",
                                subtitle: settingsManager.analyticsEnabled ? "On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.analyticsEnabled)
                                        .labelsHidden()
                                }
                            )
                            
                            // App Version
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Version")
                                        .font(.system(size: 17))
                                        .foregroundColor(.primary)
                                    
                                    Text("1.0")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        
                        // Sign Out Button (if authenticated) - iOS style
                        if authManager.isAuthenticated {
                            Button(action: {
                                Task { @MainActor in
                                    await authManager.signOut()
                                }
                            }) {
                                Text("Sign Out")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
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

// MARK: - Settings Profile Card
struct SettingsProfileCard: View {
    let name: String
    let subtitle: String
    let photoURL: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Picture - iOS style with gradient or photo
                Group {
                    if let photoURL = photoURL, let url = URL(string: photoURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.0, green: 0.478, blue: 1.0),
                                            Color(red: 0.345, green: 0.337, blue: 0.839)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Text(String(name.prefix(1)).uppercased())
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.0, green: 0.478, blue: 1.0), // iOS Blue
                                        Color(red: 0.345, green: 0.337, blue: 0.839) // Purple
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Group {
                                    if name == "Sign In" {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    } else {
                                        Text(String(name.prefix(1)).uppercased())
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Group
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            // Add subtle shadow like iOS
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
    }
}

// MARK: - Settings Row
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showDivider: Bool = true
    @ViewBuilder let trailing: Trailing
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icon - iOS style with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 16, weight: .medium))
                }
                
                // Title and Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Trailing view (toggle, chevron, etc.)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            
            // Divider - only show if not last item
            if showDivider {
                Divider()
                    .padding(.leading, 56) // Align with text after icon
                    .opacity(0.3)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(AudioManager())
}
