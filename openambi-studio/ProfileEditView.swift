import SwiftUI
import PhotosUI
import UIKit

struct ProfileEditView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Generate gradient colors based on name (matching SettingsProfileCardContent)
    private var gradientColors: [Color] {
        let name = authManager.currentUser?.friendlyName ?? "U"
        let colors: [[Color]] = [
            [Color(red: 1.0, green: 0.4, blue: 0.6), Color(red: 1.0, green: 0.6, blue: 0.8)],
            [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.6, green: 0.9, blue: 1.0)],
            [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.8, green: 0.6, blue: 1.0)],
            [Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 1.0, green: 0.9, blue: 0.5)],
            [Color(red: 0.3, green: 0.9, blue: 0.6), Color(red: 0.5, green: 1.0, blue: 0.7)],
        ]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        ZStack {
            // Dark mode background
            AppTheme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // Profile Photo Section
                    profilePhotoSection
                        .padding(.top, AppSpacing.md)
                    
                    // Display Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROFILE INFORMATION")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.tertiaryText)
                            .padding(.horizontal, AppSpacing.sm)
                        
                        SettingsGroup {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                            )
                                        
                                        Image(systemName: "person.fill")
                                            .foregroundColor(SoundColor.rain)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    
                                    TextField("Display Name", text: $displayName)
                                        .textInputAutocapitalization(.words)
                                        .foregroundColor(.white)
                                        .font(.system(size: 17))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        
                        Text("This name will be displayed instead of your email address.")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.quaternaryText)
                            .padding(.horizontal, AppSpacing.sm + 4)
                    }
                    
                    // Account Information Section (read-only)
                    if let email = authManager.currentUser?.email {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ACCOUNT INFORMATION")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.tertiaryText)
                                .padding(.horizontal, AppSpacing.sm)
                            
                            SettingsGroup {
                                SettingsRow(
                                    icon: "envelope.fill",
                                    iconColor: SoundColor.ocean,
                                    title: "Email",
                                    subtitle: email,
                                    showDivider: false,
                                    trailing: { EmptyView() }
                                )
                            }
                            .padding(.horizontal, AppSpacing.sm)
                            
                            Text("Your email address cannot be changed.")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.quaternaryText)
                                .padding(.horizontal, AppSpacing.sm + 4)
                        }
                    }
                    
                    // Save Button
                    PrimaryButton(
                        "Save Changes",
                        icon: "checkmark",
                        color: AppTheme.accent,
                        isLoading: isLoading,
                        isDisabled: displayName.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        saveProfile()
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.top, AppSpacing.sm)
                    
                    Spacer()
                        .frame(height: AppSpacing.xl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(isLoading || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .foregroundColor(AppTheme.primary)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onAppear {
            // Initialize display name from current user
            if let user = authManager.currentUser {
                displayName = user.displayName ?? user.fullName ?? ""
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let newItem = newItem {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            profileImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Profile Photo Section
    private var profilePhotoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Glow behind avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                    .opacity(0.3)
                
                // Profile Image
                if let profileImage = profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
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
                        .shadow(color: gradientColors[0].opacity(0.4), radius: 12, x: 0, y: 6)
                } else if let user = authManager.currentUser,
                          let photoURL = user.photoURL,
                          let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 120, height: 120)
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
                    .shadow(color: gradientColors[0].opacity(0.4), radius: 12, x: 0, y: 6)
                } else {
                    avatarPlaceholder
                }
            }
            
            // Photo Picker Button - glass styled
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("Change Photo")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 120)
            .overlay(
                Text(String((authManager.currentUser?.friendlyName ?? "U").prefix(1)).uppercased())
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
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
            .shadow(color: gradientColors[0].opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    private func saveProfile() {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Display name cannot be empty"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            // TODO: Update user profile in Supabase
            // For now, just update locally
            await MainActor.run {
                if let user = authManager.currentUser {
                    // Create updated user with new display name
                    let updatedUser = User(
                        id: user.id,
                        email: user.email,
                        fullName: user.fullName,
                        displayName: displayName.trimmingCharacters(in: .whitespaces),
                        username: user.username,
                        photoURL: user.photoURL, // TODO: Upload photo and get URL
                        createdAt: user.createdAt
                    )
                    authManager.currentUser = updatedUser
                }
                isLoading = false
                dismiss()
            }
        }
    }
}

#Preview {
    ProfileEditView(authManager: AuthManager())
}
