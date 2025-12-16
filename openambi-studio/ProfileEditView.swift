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
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Profile Photo Section
                    VStack(spacing: 20) {
                        // Profile Image
                        if let profileImage = profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                .shadow(radius: 10)
                        } else if let user = authManager.currentUser,
                                  let photoURL = user.photoURL,
                                  let url = URL(string: photoURL) {
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
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Text(String(user.friendlyName.prefix(1)).uppercased())
                                            .font(.system(size: 48, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(radius: 10)
                        } else {
                            // Default avatar with initials
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
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Text(String((authManager.currentUser?.friendlyName ?? "U").prefix(1)).uppercased())
                                        .font(.system(size: 48, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                                .shadow(radius: 10)
                        }
                        
                        // Photo Picker Button
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Change Photo")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                Section {
                    // Display Name Field
                    TextField("Display Name", text: $displayName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Profile Information")
                } footer: {
                    Text("This name will be displayed instead of your email address.")
                }
                
                if let email = authManager.currentUser?.email {
                    Section {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Account Information")
                    } footer: {
                        Text("Your email address cannot be changed.")
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isLoading || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
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
                if var user = authManager.currentUser {
                    // Create updated user with new display name
                    let updatedUser = User(
                        id: user.id,
                        email: user.email,
                        fullName: user.fullName,
                        displayName: displayName.trimmingCharacters(in: .whitespaces),
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
