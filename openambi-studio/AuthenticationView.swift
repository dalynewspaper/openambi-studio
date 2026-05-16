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
            // Always dump the raw error to the console so we can diagnose
            // the cases that `ASAuthorizationError.unknown` obscures
            // (Apple auth daemon failures, AKAuthentication errors, bundle-
            // ID/service mismatches, network drops, etc.). The visible
            // message stays editorial; the console is where the truth lives.
            let nsError = error as NSError
            print("🛑 Apple Sign In failed")
            print("   domain: \(nsError.domain)")
            print("   code:   \(nsError.code)")
            print("   desc:   \(nsError.localizedDescription)")
            if !nsError.userInfo.isEmpty {
                print("   userInfo:")
                for (key, value) in nsError.userInfo {
                    print("     \(key) = \(value)")
                }
            }
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   underlying: \(underlying.domain) / \(underlying.code) — \(underlying.localizedDescription)")
            }

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
                        // `.unknown` is a catch-all that hides several
                        // distinct causes: missing iCloud on a simulator,
                        // network failure, Apple-server outage, the bundle
                        // ID not having Sign in with Apple enabled in the
                        // Apple Developer portal, or an AKAuthentication
                        // daemon failure. Surface whatever detail the
                        // underlying NSError carries so the user (and we)
                        // get a real signal instead of a single guess.
                        let detail = friendlyUnknownDetail(from: nsError)
                        #if targetEnvironment(simulator)
                        authManager.errorMessage = "Apple couldn't complete sign in.\n\n\(detail)\n\nIn the simulator this is often a missing iCloud account (Settings ▸ Sign in to your iPhone) or that Apple's auth daemon hasn't been registered for this app. Running on a real device usually clears it."
                        #else
                        authManager.errorMessage = "Apple couldn't complete sign in.\n\n\(detail)"
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

    /// Best-effort short, readable detail extracted from the underlying
    /// NSError. Falls back to `localizedDescription` when nothing better
    /// is available.
    private func friendlyUnknownDetail(from nsError: NSError) -> String {
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return "[\(underlying.domain) \(underlying.code)] \(underlying.localizedDescription)"
        }
        if let reason = nsError.localizedFailureReason {
            return reason
        }
        return nsError.localizedDescription
    }
}

#Preview {
    AuthenticationView(authManager: AuthManager())
}
