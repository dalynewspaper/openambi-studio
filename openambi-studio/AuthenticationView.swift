import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @ObservedObject var authManager: AuthManager
    @State private var showContent = false
    @State private var isAppleSignInAvailable = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background matching SimpleLoadingView
            DynamicLoadingBackground(trackName: "Rain")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Minimal branding - matching SimpleLoadingView
                VStack(spacing: 32) {
                    // Brand name and tagline
                    VStack(spacing: 10) {
                        Text("openambi")
                            .font(.custom("Kode Mono", size: 40))
                            .foregroundColor(.white)
                            .kerning(2.5)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                        
                        Text("your ambient soundscape")
                            .font(.system(size: AppTypography.subheadline, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
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
            // Check if Sign in with Apple is available
            checkAppleSignInAvailability()
            
            withAnimation(.easeOut(duration: 0.3)) {
                showContent = true
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // Dismiss authentication view after successful sign in
            if isAuthenticated && !authManager.isLoading {
                print("✅ Authentication successful, dismissing sheet in 0.3 seconds")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        }
        .onChange(of: authManager.isLoading) { _, isLoading in
            // Also check when loading completes
            if !isLoading && authManager.isAuthenticated {
                print("✅ Loading completed and user is authenticated, dismissing sheet")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
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
            if isAppleSignInAvailable {
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
            
            // Skip option
            Button(action: {
                dismiss()
            }) {
                Text("Continue without signing in")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.tertiaryText)
            }
            } else {
                // Fallback if Sign in with Apple is not available
                Button(action: {
                    authManager.errorMessage = "Sign in with Apple is not available on this device or is not properly configured."
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Sign in with Apple Unavailable")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(16)
                }
                .disabled(true)
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Helpers
    private func checkAppleSignInAvailability() {
        // Check if we're on a device that supports Sign in with Apple
        // Note: This is a basic check - the actual availability depends on
        // proper configuration in Xcode and Apple Developer Portal
        #if targetEnvironment(simulator)
        // Sign in with Apple doesn't work in simulator
        print("⚠️ Running in simulator - Sign in with Apple may not work")
        #endif
        
        // The button itself will handle availability, but we can log diagnostics
        print("🔍 Checking Sign in with Apple availability...")
        print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        
        // Check if the capability is present in entitlements
        if let entitlements = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.applesignin") {
            print("   ✅ Sign in with Apple entitlement found")
        } else {
            print("   ⚠️ Sign in with Apple entitlement not found in Info.plist")
            print("   ⚠️ Make sure the capability is added in Xcode")
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            print("✅ Apple Sign In authorization received")
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                print("✅ Apple ID credential extracted successfully")
                Task {
                    await authManager.handleAppleIDCredential(appleIDCredential)
                }
            } else {
                print("❌ Failed to extract Apple ID credential from authorization")
                Task { @MainActor in
                    authManager.errorMessage = "Failed to process Apple Sign In. Please try again."
                    authManager.isLoading = false
                }
            }
        case .failure(let error):
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
            print("   Error details: \(error)")
            
            Task { @MainActor in
                if let authError = error as? ASAuthorizationError {
                    print("   ASAuthorizationError code: \(authError.code.rawValue)")
                    
                    switch authError.code {
                    case .canceled:
                        print("   User canceled authentication")
                        authManager.errorMessage = nil
                    case .failed:
                        print("   Authentication failed")
                        authManager.errorMessage = "Apple Sign In failed. Please ensure Sign in with Apple is enabled for this app in Settings."
                    case .invalidResponse:
                        print("   Invalid response from Apple")
                        authManager.errorMessage = "Invalid response from Apple. Please try again."
                    case .notHandled:
                        print("   Authentication not handled - capability may be missing")
                        authManager.errorMessage = "Sign in with Apple is not available. Please ensure the app is properly configured."
                    case .unknown:
                        print("   Unknown authentication error")
                        // Check for specific error codes that indicate configuration issues
                        if let nsError = error as NSError? {
                            print("   NSError domain: \(nsError.domain), code: \(nsError.code)")
                            if nsError.code == -7026 {
                                authManager.errorMessage = "Sign in with Apple is not configured. Please contact support."
                            } else {
                                authManager.errorMessage = "An unknown error occurred (code: \(nsError.code)). Please try again."
                            }
                        } else {
                            authManager.errorMessage = "An unknown error occurred. Please try again."
                        }
                    @unknown default:
                        print("   Unknown error code: \(authError.code.rawValue)")
                        authManager.errorMessage = "Authentication error occurred. Please try again."
                    }
                } else {
                    // Check for NSError with specific codes
                    if let nsError = error as NSError? {
                        print("   NSError domain: \(nsError.domain), code: \(nsError.code)")
                        if nsError.code == -7026 {
                            authManager.errorMessage = "Sign in with Apple is not configured for this app. Please ensure the capability is enabled in Xcode and the App ID is configured in Apple Developer Portal."
                        } else {
                            authManager.errorMessage = "Sign in failed: \(error.localizedDescription)"
                        }
                    } else {
                        authManager.errorMessage = error.localizedDescription
                    }
                }
                authManager.isLoading = false
            }
        }
    }
}

#Preview {
    AuthenticationView(authManager: AuthManager())
}
