import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @ObservedObject var authManager: AuthManager
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background matching SimpleLoadingView
            DynamicLoadingBackground(trackName: "Rain")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Minimal branding - matching SimpleLoadingView
                VStack(spacing: 32) {
                    // "openambi" text - matching SimpleLoadingView style
                    Text("openambi")
                        .font(.custom("Kode Mono", size: 40))
                        .foregroundColor(.white)
                        .kerning(2.5)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                    
                    // Minimal authentication card
                    authenticationCard
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                showContent = true
            }
        }
    }
    
    
    // MARK: - Authentication Card
    private var authenticationCard: some View {
        VStack(spacing: 24) {
            // Error message
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.15))
                    )
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Sign In with Apple Button - Minimal style
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    handleAppleSignIn(result: result)
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .disabled(authManager.isLoading)
            .overlay {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                }
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Helpers
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    await authManager.handleAppleIDCredential(appleIDCredential)
                }
            }
        case .failure(let error):
            Task { @MainActor in
                if let authError = error as? ASAuthorizationError {
                    switch authError.code {
                    case .canceled:
                        authManager.errorMessage = nil
                    case .failed:
                        authManager.errorMessage = "Apple Sign In failed. Please try again or use another method."
                    case .invalidResponse:
                        authManager.errorMessage = "Invalid response. Please try again."
                    case .notHandled:
                        authManager.errorMessage = "Sign in with Apple is not available on this device."
                    case .unknown:
                        // The `unknown` code is what the Authentication Services
                        // framework throws when it can't reach Apple ID — on a
                        // simulator this almost always means there's no iCloud
                        // account signed into the sim itself. Disambiguating
                        // the copy here saves a confused round-trip during
                        // local development and beta testing.
                        #if targetEnvironment(simulator)
                        authManager.errorMessage = "Sign in with Apple needs an iCloud account on this simulator. Open the simulator's Settings app and sign in to iCloud first — or run on a real device."
                        #else
                        authManager.errorMessage = "Sign in with Apple couldn't reach Apple ID. Check your connection and try again."
                        #endif
                    @unknown default:
                        authManager.errorMessage = "Authentication error. Please try again."
                    }
                } else {
                    authManager.errorMessage = error.localizedDescription
                }
                authManager.isLoading = false
            }
        }
    }
}

#Preview {
    AuthenticationView(authManager: AuthManager())
}
