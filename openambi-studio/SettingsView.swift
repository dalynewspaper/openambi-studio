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
    @State private var showUserRecordings = false
    @State private var navigationPath = NavigationPath()
    @State private var showFadeInDurationPicker = false
    @State private var showAudioQualityPicker = false
    @State private var showDownloadQualityPicker = false
    @State private var showThemePicker = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Dark mode background with liquid glass aesthetic
                AppTheme.background
                    .ignoresSafeArea(.all)
                
                GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Settings title at top - enhanced for dark mode
                        HStack {
                            Text("Settings")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        
                        // Account Section
                        if authManager.isAuthenticated, let user = authManager.currentUser {
                            NavigationLink(value: "profileEdit") {
                                SettingsProfileCardContent(
                                    name: user.friendlyName,
                                    subtitle: "Tap to edit profile",
                                    photoURL: user.photoURL
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.md)
                        } else {
                            SettingsProfileCard(
                                name: "Sign In",
                                subtitle: "Sign in to sync your mixes and preferences",
                                photoURL: nil,
                                onTap: {
                                    withAnimation(AppTheme.Animation.micro) {
                                        showSignIn = true
                                    }
                                }
                            )
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.md)
                        }
                        
                        // Account Settings Group (if authenticated)
                        if authManager.isAuthenticated {
                            settingsSectionHeader("ACCOUNT")
                            SettingsGroup {
                                Button(action: {
                                    withAnimation(AppTheme.Animation.micro) {
                                        showUserRecordings = true
                                    }
                                }) {
                                    SettingsRow(
                                        icon: "mic.fill",
                                        iconColor: SoundColor.river,
                                        title: "My Recordings",
                                        showDivider: true,
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    // Open subscription management
                                }) {
                                    SettingsRow(
                                        icon: "creditcard",
                                        iconColor: SoundColor.ocean,
                                        title: "Manage Subscription",
                                        showDivider: true,
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    withAnimation(AppTheme.Animation.micro) {
                                        showDeleteAccount = true
                                    }
                                }) {
                                    SettingsRow(
                                        icon: "trash",
                                        iconColor: .red,
                                        title: "Delete Account",
                                        showDivider: false,
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.md)
                        }
                        
                        // Playback Settings Group
                        settingsSectionHeader("PLAYBACK")
                        SettingsGroup {
                            Button(action: {
                                withAnimation(AppTheme.Animation.micro) {
                                    showFadeInDurationPicker = true
                                }
                            }) {
                                SettingsRow(
                                    icon: "waveform",
                                    iconColor: SoundColor.rain,
                                    title: "Fade In Duration",
                                    subtitle: FadeDuration(rawValue: settingsManager.fadeInDuration)?.displayName ?? "1s",
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            SettingsRow(
                                icon: "waveform.path",
                                iconColor: SoundColor.rain,
                                title: "Fade Out on Exit",
                                subtitle: settingsManager.fadeOutOnExit ? "\(Int(settingsManager.fadeOutDuration))s" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.fadeOutOnExit)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                            
                            SettingsRow(
                                icon: "lock.fill",
                                iconColor: SoundColor.birds,
                                title: "Background Playback",
                                subtitle: "Play audio when screen is locked",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.backgroundPlayback)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                            
                            SettingsRow(
                                icon: "arrow.clockwise",
                                iconColor: SoundColor.ocean,
                                title: "Resume Last Mix",
                                subtitle: settingsManager.resumeLastMix ? "On" : "Off",
                                showDivider: false,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.resumeLastMix)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.md)
                        
                        // Audio Quality Settings Group
                        settingsSectionHeader("SOUND QUALITY")
                        SettingsGroup {
                            Button(action: {
                                withAnimation(AppTheme.Animation.micro) {
                                    showAudioQualityPicker = true
                                }
                            }) {
                                SettingsRow(
                                    icon: "music.note",
                                    iconColor: SoundColor.river,
                                    title: "Audio Quality",
                                    subtitle: settingsManager.audioQuality.rawValue,
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                withAnimation(AppTheme.Animation.micro) {
                                    showDownloadQualityPicker = true
                                }
                            }) {
                                SettingsRow(
                                    icon: "arrow.down.circle",
                                    iconColor: SoundColor.ocean,
                                    title: "Download Quality",
                                    subtitle: settingsManager.downloadQuality.rawValue,
                                    showDivider: false,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.md)
                        
                        // Appearance Settings Group
                        settingsSectionHeader("APPEARANCE")
                        SettingsGroup {
                            Button(action: {
                                withAnimation(AppTheme.Animation.micro) {
                                    showThemePicker = true
                                }
                            }) {
                                SettingsRow(
                                    icon: "paintbrush",
                                    iconColor: SoundColor.river,
                                    title: "Theme",
                                    subtitle: settingsManager.theme.rawValue,
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            SettingsRow(
                                icon: "sparkles",
                                iconColor: SoundColor.rain,
                                title: "Visual Effects",
                                subtitle: settingsManager.liquidGlassEffects ? "Liquid Glass On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.liquidGlassEffects)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                            
                            SettingsRow(
                                icon: "figure.walk",
                                iconColor: SoundColor.ocean,
                                title: "Reduce Motion",
                                subtitle: settingsManager.reduceMotion ? "On" : "Off",
                                showDivider: false,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.reduceMotion)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.md)
                        
                        // Notifications Settings Group
                        settingsSectionHeader("NOTIFICATIONS")
                        SettingsGroup {
                            SettingsRow(
                                icon: "bell",
                                iconColor: SoundColor.fireplace,
                                title: "New Scenes",
                                subtitle: settingsManager.notificationsNewScenes ? "On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.notificationsNewScenes)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                            
                            SettingsRow(
                                icon: "calendar",
                                iconColor: SoundColor.ocean,
                                title: "Daily Mix Suggestions",
                                subtitle: settingsManager.notificationsDailyMix ? "On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.notificationsDailyMix)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                            
                            SettingsRow(
                                icon: "heart",
                                iconColor: SoundColor.tibetanBowl,
                                title: "Relaxation Reminders",
                                subtitle: settingsManager.notificationsRelaxation ? "On" : "Off",
                                showDivider: false,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.notificationsRelaxation)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.md)
                        
                        // Data & Sync Settings Group
                        settingsSectionHeader("DATA & PRIVACY")
                        SettingsGroup {
                            SettingsRow(
                                icon: "icloud",
                                iconColor: SoundColor.ocean,
                                title: "iCloud Sync",
                                subtitle: settingsManager.iCloudSync ? "On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.iCloudSync)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                            
                            Button(action: {
                                withAnimation(AppTheme.Animation.micro) {
                                    settingsManager.clearCachedAudio()
                                }
                            }) {
                                SettingsRow(
                                    icon: "trash.circle",
                                    iconColor: SoundColor.fireplace,
                                    title: "Clear Cached Audio",
                                    subtitle: "Free up storage space",
                                    showDivider: false,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.md)
                        
                        // About & Privacy Settings Group
                        settingsSectionHeader("ABOUT")
                        SettingsGroup {
                            Button(action: {
                                withAnimation(AppTheme.Animation.micro) {
                                    showPrivacyPolicy = true
                                }
                            }) {
                                SettingsRow(
                                    icon: "hand.raised",
                                    iconColor: SoundColor.ocean,
                                    title: "Privacy Policy",
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                withAnimation(AppTheme.Animation.micro) {
                                    showTermsOfService = true
                                }
                            }) {
                                SettingsRow(
                                    icon: "doc.text",
                                    iconColor: SoundColor.fan,
                                    title: "Terms of Service",
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                withAnimation(AppTheme.Animation.micro) {
                                    showAcknowledgements = true
                                }
                            }) {
                                SettingsRow(
                                    icon: "info.circle",
                                    iconColor: SoundColor.rain,
                                    title: "Acknowledgements",
                                    showDivider: true,
                                    trailing: {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.quaternaryText) // Phase 4: Vibrant color
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            SettingsRow(
                                icon: "chart.bar",
                                iconColor: SoundColor.fan,
                                title: "Analytics & Diagnostics",
                                subtitle: settingsManager.analyticsEnabled ? "On" : "Off",
                                showDivider: true,
                                trailing: {
                                    Toggle("", isOn: $settingsManager.analyticsEnabled)
                                        .labelsHidden()
                                        .tint(AppTheme.primary)
                                }
                            )
                            
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.md)
                        
                        // App version footer - centered, minimal
                        Text("openambi v1.0")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.quaternaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xs)
                            .padding(.bottom, AppSpacing.sm)
                        
                        // Sign Out Button (if authenticated) - Liquid Glass style
                        if authManager.isAuthenticated {
                            Button(action: {
                                Task { @MainActor in
                                    await authManager.signOut()
                                }
                            }) {
                                Text("Sign Out")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .liquidGlass(intensity: 0.6, cornerRadius: 16, blurIntensity: .light, opacityLevel: .content)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.md)
                        }
                        
                        // Bottom padding for safe scrolling
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.bottom + AppSpacing.md)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "profileEdit" {
                    ProfileEditView(authManager: authManager)
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
        .sheet(isPresented: $showUserRecordings) {
            UserRecordingsView()
                .environmentObject(authManager)
                .environmentObject(audioManager)
        }
        .navigationDestination(for: String.self) { destination in
            if destination == "profileEdit" {
                ProfileEditView(authManager: authManager)
            }
        }
        .sheet(isPresented: $showFadeInDurationPicker) {
            FadeDurationPickerView(settingsManager: settingsManager)
        }
        .sheet(isPresented: $showAudioQualityPicker) {
            AudioQualityPickerView(settingsManager: settingsManager)
        }
        .sheet(isPresented: $showDownloadQualityPicker) {
            DownloadQualityPickerView(settingsManager: settingsManager)
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView(settingsManager: settingsManager)
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // Close sign-in sheet when user successfully signs in
            if isAuthenticated {
                print("✅ User authenticated in SettingsView, closing sign-in sheet")
                showSignIn = false
            }
        }
        .onChange(of: authManager.isLoading) { _, isLoading in
            // Also check when loading completes - ensure sheet closes
            if !isLoading && authManager.isAuthenticated && showSignIn {
                print("✅ Loading completed in SettingsView, closing sign-in sheet")
                showSignIn = false
            }
        }
        }
    }
    
    // MARK: - Section Header Helper
    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppColors.tertiaryText)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.sm + 4)
            .padding(.bottom, 6)
    }
}

// MARK: - Account Details View
struct AccountDetailsView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        if let user = authManager.currentUser {
                            // Account Information Section
                            Text("ACCOUNT INFORMATION")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.tertiaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.top, AppSpacing.md)
                                .padding(.bottom, 8)
                            
                            SettingsGroup {
                                if let email = user.email {
                                    SettingsRow(
                                        icon: "envelope.fill",
                                        iconColor: SoundColor.ocean,
                                        title: "Email",
                                        subtitle: email,
                                        showDivider: user.fullName != nil,
                                        trailing: { EmptyView() }
                                    )
                                }
                                
                                if let fullName = user.fullName {
                                    SettingsRow(
                                        icon: "person.fill",
                                        iconColor: SoundColor.rain,
                                        title: "Name",
                                        subtitle: fullName,
                                        showDivider: false,
                                        trailing: { EmptyView() }
                                    )
                                }
                            }
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.md)
                            
                            // Subscription Section
                            SettingsGroup {
                                Button(action: {
                                    // Open subscription management
                                }) {
                                    SettingsRow(
                                        icon: "creditcard",
                                        iconColor: SoundColor.river,
                                        title: "Manage Subscription",
                                        showDivider: false,
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.quaternaryText)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, AppSpacing.sm)
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
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
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 28) {
                    // Warning icon
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                            )
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                    }
                    .padding(.top, 40)
                    
                    Text("Delete Account")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("This action cannot be undone. All your data, saved mixes, and preferences will be permanently deleted.")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    // Confirmation text field - glass styled
                    TextField("Type DELETE to confirm", text: $confirmText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            confirmText == "DELETE" ? Color.red.opacity(0.5) : Color.white.opacity(0.15),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .padding(.horizontal, 32)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    
                    // Delete button - red glass treatment
                    Button(action: {
                        // Delete account logic
                        dismiss()
                    }) {
                        Text("Delete Account")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.regularMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.red.opacity(confirmText == "DELETE" ? 0.5 : 0.15),
                                                        Color.red.opacity(confirmText == "DELETE" ? 0.35 : 0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        Color.red.opacity(confirmText == "DELETE" ? 0.6 : 0.2),
                                        lineWidth: 1.5
                                    )
                            }
                            .shadow(color: confirmText == "DELETE" ? Color.red.opacity(0.3) : .clear, radius: 12, x: 0, y: 4)
                    }
                    .disabled(confirmText != "DELETE")
                    .opacity(confirmText == "DELETE" ? 1.0 : 0.5)
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
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
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy Policy")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text("Your privacy is important to us. This Privacy Policy explains how OpenAmbi collects, uses, and protects your information.")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.secondaryText)
                            .padding(.top, 8)
                        
                        // Add more privacy policy content here
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
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
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Service")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text("By using OpenAmbi, you agree to these Terms of Service.")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.secondaryText)
                            .padding(.top, 8)
                        
                        // Add more terms content here
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
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
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Acknowledgements")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text("OpenAmbi uses the following open-source libraries and frameworks:")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.secondaryText)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            AcknowledgementRow(name: "SwiftUI", description: "Apple's declarative UI framework", showDivider: true)
                            AcknowledgementRow(name: "AVFoundation", description: "Apple's audio framework", showDivider: true)
                            AcknowledgementRow(name: "Supabase", description: "Backend and authentication", showDivider: false)
                        }
                        .contentSection(cornerRadius: 20, padding: 0)
                        .padding(.top, 16)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Acknowledgements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }
}

struct AcknowledgementRow: View {
    let name: String
    let description: String
    var showDivider: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if showDivider {
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.leading, 16)
            }
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
            SettingsProfileCardContent(name: name, subtitle: subtitle, photoURL: photoURL)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Profile Card Content (for use in NavigationLink)
struct SettingsProfileCardContent: View {
    let name: String
    let subtitle: String
    let photoURL: String?
    
    @State private var isPressed = false
    
    // Generate fun gradient colors based on name
    private var gradientColors: [Color] {
        let colors: [[Color]] = [
            [Color(red: 1.0, green: 0.4, blue: 0.6), Color(red: 1.0, green: 0.6, blue: 0.8)], // Pink
            [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.6, green: 0.9, blue: 1.0)], // Sky Blue
            [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.8, green: 0.6, blue: 1.0)], // Purple
            [Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 1.0, green: 0.9, blue: 0.5)], // Orange
            [Color(red: 0.3, green: 0.9, blue: 0.6), Color(red: 0.5, green: 1.0, blue: 0.7)], // Green
        ]
        // Use name hash to pick consistent color
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        HStack(spacing: 16) {
                // Profile Picture with fun design
                ZStack {
                    // Animated background glow
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .blur(radius: 8)
                        .opacity(0.3)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                    
                    // Profile Picture
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
                                            colors: gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Text(String(name.prefix(1)).uppercased())
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(color: gradientColors[0].opacity(0.4), radius: 8, x: 0, y: 4)
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Group {
                                        if name == "Sign In" {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 36))
                                                .foregroundColor(.white)
                                        } else {
                                            Text(String(name.prefix(1)).uppercased())
                                                .font(.system(size: 32, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.8), .white.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                )
                                .shadow(color: gradientColors[0].opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .rotationEffect(.degrees(isPressed ? -5 : 0))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.secondaryText) // Phase 4: Vibrant color
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Fun animated chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(gradientColors[0])
                    .font(.system(size: 16, weight: .semibold))
                    .offset(x: isPressed ? 4 : 0)
                    .animation(AppTheme.Animation.micro, value: isPressed)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .liquidGlass(intensity: 0.85, cornerRadius: 20, blurIntensity: .medium, opacityLevel: .content)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                gradientColors[0].opacity(0.4),
                                gradientColors[1].opacity(0.2),
                                gradientColors[0].opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(AppTheme.Animation.liquidSpring, value: isPressed)
        }
    }

// MARK: - Settings Group
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        // Phase 6: Use standard material for content (not Liquid Glass)
        .contentSection(cornerRadius: 20, padding: 0)
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
                // Icon - Liquid Glass style with neutral translucent background
                ZStack {
                    // Neutral translucent material background (works with any icon color)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                        .overlay(
                            // Subtle white tint overlay for liquid glass effect
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            // Subtle border - neutral white, very low opacity
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    
                    // Colored icon on top
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                // Title and Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.secondaryText) // Phase 4: Vibrant color
                    }
                }
                
                Spacer()
                
                // Trailing view (toggle, chevron, etc.)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Divider - only show if not last item (dark mode style)
            if showDivider {
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.leading, 60) // Align with text after icon
            }
        }
    }
}

// MARK: - Fade Duration Picker View
struct FadeDurationPickerView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsGroup {
                            ForEach(Array(FadeDuration.allCases.enumerated()), id: \.element) { index, duration in
                                Button(action: {
                                    withAnimation(AppTheme.Animation.micro) {
                                        settingsManager.fadeInDuration = duration.rawValue
                                        dismiss()
                                    }
                                }) {
                                    SettingsPickerRow(
                                        title: duration.displayName,
                                        isSelected: FadeDuration(rawValue: settingsManager.fadeInDuration) == duration,
                                        showDivider: index < FadeDuration.allCases.count - 1
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.top, AppSpacing.md)
                    }
                }
            }
            .navigationTitle("Fade In Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }
}

// MARK: - Audio Quality Picker View
struct AudioQualityPickerView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsGroup {
                            ForEach(Array(AudioQuality.allCases.enumerated()), id: \.element) { index, quality in
                                Button(action: {
                                    withAnimation(AppTheme.Animation.micro) {
                                        settingsManager.audioQuality = quality
                                        dismiss()
                                    }
                                }) {
                                    SettingsPickerRow(
                                        title: quality.rawValue,
                                        isSelected: settingsManager.audioQuality == quality,
                                        showDivider: index < AudioQuality.allCases.count - 1
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.top, AppSpacing.md)
                    }
                }
            }
            .navigationTitle("Audio Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }
}

// MARK: - Download Quality Picker View
struct DownloadQualityPickerView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsGroup {
                            ForEach(Array(DownloadQuality.allCases.enumerated()), id: \.element) { index, quality in
                                Button(action: {
                                    withAnimation(AppTheme.Animation.micro) {
                                        settingsManager.downloadQuality = quality
                                        dismiss()
                                    }
                                }) {
                                    SettingsPickerRow(
                                        title: quality.rawValue,
                                        isSelected: settingsManager.downloadQuality == quality,
                                        showDivider: index < DownloadQuality.allCases.count - 1
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.top, AppSpacing.md)
                    }
                }
            }
            .navigationTitle("Download Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }
}

// MARK: - Theme Picker View
struct ThemePickerView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        SettingsGroup {
                            ForEach(Array(ThemePreference.allCases.enumerated()), id: \.element) { index, theme in
                                Button(action: {
                                    withAnimation(AppTheme.Animation.micro) {
                                        settingsManager.theme = theme
                                        dismiss()
                                    }
                                }) {
                                    SettingsPickerRow(
                                        title: theme.rawValue,
                                        isSelected: settingsManager.theme == theme,
                                        showDivider: index < ThemePreference.allCases.count - 1
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.top, AppSpacing.md)
                    }
                }
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }
}

// MARK: - Settings Picker Row (reusable for picker sheets)
struct SettingsPickerRow: View {
    let title: String
    let isSelected: Bool
    var showDivider: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if showDivider {
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.leading, 16)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(AudioManager())
}
