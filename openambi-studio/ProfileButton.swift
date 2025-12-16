import SwiftUI

struct ProfileButton: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showAuthSheet = false
    @State private var showSettingsSheet = false
    
    var body: some View {
        Button(action: {
            if authManager.isAuthenticated {
                showSettingsSheet = true
            } else {
                showAuthSheet = true
            }
        }) {
            Image(systemName: authManager.isAuthenticated ? "person.circle.fill" : "person.circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: authManager.isAuthenticated 
                            ? [SoundColor.rain, SoundColor.ocean]
                            : [Color.white.opacity(0.8), Color.white.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthenticationView(authManager: authManager)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // Close auth sheet when user successfully signs in
            if isAuthenticated {
                showAuthSheet = false
            }
        }
    }
}


#Preview {
    ProfileButton()
        .environmentObject(AuthManager())
}
