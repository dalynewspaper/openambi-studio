import Foundation
import SwiftUI
import Security
import AuthenticationServices

// MARK: - User Model
struct User: Identifiable, Codable {
    let id: UUID
    let email: String?
    let fullName: String?
    let displayName: String?
    let photoURL: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case displayName = "display_name"
        case photoURL = "photo_url"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try? container.decode(String.self, forKey: .email)
        fullName = try? container.decode(String.self, forKey: .fullName)
        displayName = try? container.decode(String.self, forKey: .displayName)
        photoURL = try? container.decode(String.self, forKey: .photoURL)
        
        // Handle UUID as string from Supabase
        if let idString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idString) {
            id = uuid
        } else {
            // Fallback: generate new UUID if parsing fails
            id = UUID()
        }
        
        // Handle optional date
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        } else {
            createdAt = nil
        }
    }
    
    // Regular initializer for creating User instances
    init(id: UUID, email: String?, fullName: String?, displayName: String?, photoURL: String?, createdAt: Date?) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.displayName = displayName
        self.photoURL = photoURL
        self.createdAt = createdAt
    }
    
    // Computed property for friendly display name
    var friendlyName: String {
        return displayName ?? fullName ?? email?.components(separatedBy: "@").first ?? "User"
    }
}

// MARK: - Auth Manager
class AuthManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let supabaseUrl = SupabaseConfig.url
    private let supabaseKey = SupabaseConfig.anonKey
    private let urlSession = PerformanceOptimizer.shared.urlSession
    
    // Keychain service for secure token storage
    private let keychainService = "com.openambi.auth"
    private let accessTokenKey = "supabase_access_token"
    private let refreshTokenKey = "supabase_refresh_token"
    private let userKey = "current_user"
    
    override init() {
        super.init()
        // Check for existing session on init
        Task {
            await checkExistingSession()
        }
    }
    
    // MARK: - Handle Apple ID Credential (called from AuthenticationView)
    func handleAppleIDCredential(_ credential: ASAuthorizationAppleIDCredential) async {
        await processAppleIDCredential(credential)
    }
    
    // MARK: - Sign In with Google
    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        // Construct Supabase OAuth URL for Google
        let redirectURL = "\(Bundle.main.bundleIdentifier ?? "co.fourthquarterstudio.openambi"):/auth/callback"
        let state = UUID().uuidString
        
        // Save state for verification
        await saveKeychainValue(key: "oauth_state", value: state)
        
        let googleAuthURL = "\(supabaseUrl)/auth/v1/authorize?provider=google&redirect_to=\(redirectURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: googleAuthURL) else {
            await MainActor.run {
                errorMessage = "Invalid authentication URL"
            }
            return
        }
        
        // Use ASWebAuthenticationSession for OAuth flow
        await MainActor.run {
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Bundle.main.bundleIdentifier ?? "co.fourthquarterstudio.openambi",
                completionHandler: { [weak self] callbackURL, error in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        
                        if let error = error {
                            self.errorMessage = error.localizedDescription
                            return
                        }
                        
                        guard let callbackURL = callbackURL else {
                            self.errorMessage = "Authentication cancelled"
                            return
                        }
                        
                        // Extract code from callback URL
                        if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                            await self.exchangeOAuthCode(code: code, provider: "google")
                        } else {
                            self.errorMessage = "Failed to extract authorization code"
                        }
                    }
                }
            )
            
            session.presentationContextProvider = self
            session.start()
        }
    }
    
    // MARK: - Exchange OAuth Code for Tokens
    private func exchangeOAuthCode(code: String, provider: String) async {
        let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=authorization_code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let redirectURL = "\(Bundle.main.bundleIdentifier ?? "co.fourthquarterstudio.openambi"):/auth/callback"
        let body: [String: Any] = [
            "auth_code": code,
            "provider": provider,
            "redirect_to": redirectURL
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                var errorMsg = errorData?["error_description"] as? String ?? errorData?["msg"] as? String ?? "Authentication failed"
                
                // Provide helpful error messages
                if errorMsg.contains("missing OAuth secret") || errorMsg.contains("Unsupported provider") {
                    errorMsg = "\(provider.capitalized) Sign In is not configured in Supabase. Please configure it in your Supabase Dashboard → Authentication → Providers → \(provider.capitalized)"
                }
                
                throw AuthError.oauthFailed(errorMsg)
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            // Save tokens to keychain
            await saveTokens(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
            
            // Save user
            await MainActor.run {
                currentUser = authResponse.user
                isAuthenticated = true
            }
            
            // Save user to keychain for persistence
            await saveUser(authResponse.user)
            
            print("✅ User signed in successfully with \(provider)")
        } catch {
            let errorMsg = error.localizedDescription
            await MainActor.run {
                errorMessage = errorMsg
            }
        }
    }
    
    // MARK: - Process Apple ID Credential (private helper)
    private func processAppleIDCredential(_ credential: ASAuthorizationAppleIDCredential) async {
        // Get identity token
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            await MainActor.run {
                errorMessage = "Failed to get identity token"
                isLoading = false
            }
            return
        }
        
        // Exchange with Supabase
        let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "provider": "apple",
            "id_token": identityToken
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                var errorMsg = errorData?["error_description"] as? String ?? errorData?["msg"] as? String ?? "Apple Sign In failed"
                
                // Provide helpful error messages
                if errorMsg.contains("missing OAuth secret") || errorMsg.contains("Unsupported provider") {
                    errorMsg = "Apple Sign In is not configured in Supabase. Please configure it in your Supabase Dashboard → Authentication → Providers → Apple"
                }
                
                throw AuthError.oauthFailed(errorMsg)
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            // Save tokens to keychain
            await saveTokens(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
            
            // Create user from Apple credential (use data from Supabase response, fallback to credential)
            let email = authResponse.user.email ?? credential.email
            let fullName = credential.fullName
            let displayName = fullName != nil ? "\(fullName!.givenName ?? "") \(fullName!.familyName ?? "")".trimmingCharacters(in: .whitespaces) : authResponse.user.fullName
            
            let user = User(
                id: authResponse.user.id,
                email: email,
                fullName: displayName,
                displayName: authResponse.user.displayName ?? displayName,
                photoURL: authResponse.user.photoURL,
                createdAt: authResponse.user.createdAt
            )
            
            // Save user
            await MainActor.run {
                currentUser = user
                isAuthenticated = true
                isLoading = false
            }
            
            // Save user to keychain for persistence
            await saveUser(user)
            
            print("✅ User signed in successfully with Apple")
        } catch {
            let errorMsg = error.localizedDescription
            await MainActor.run {
                errorMessage = errorMsg
                isLoading = false
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        // Clear tokens from keychain
        await clearTokens()
        
        // Clear user data
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
            errorMessage = nil
        }
        
        print("✅ User signed out")
    }
    
    // MARK: - Check Existing Session
    func checkExistingSession() async {
        // Try to load user from keychain
        if let user = await loadUser() {
            // Check if we have valid tokens
            if let accessToken = await getAccessToken() {
                // Verify token is still valid by making a test request
                if await verifyToken(accessToken) {
                    await MainActor.run {
                        currentUser = user
                        isAuthenticated = true
                    }
                    print("✅ Restored session for user")
                    return
                }
            }
        }
        
        // No valid session found
        await MainActor.run {
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    // MARK: - Get Access Token (for authenticated requests)
    func getAccessToken() async -> String? {
        return await getKeychainValue(key: accessTokenKey)
    }
    
    // MARK: - Verify Token
    private func verifyToken(_ token: String) async -> Bool {
        let url = URL(string: "\(supabaseUrl)/auth/v1/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
    
    // MARK: - Refresh Token (if needed)
    func refreshTokenIfNeeded() async throws -> String? {
        guard let refreshToken = await getKeychainValue(key: refreshTokenKey) else {
            return nil
        }
        
        let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            await saveTokens(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken)
            
            return authResponse.accessToken
        } catch {
            return nil
        }
    }
    
    // MARK: - Keychain Helpers
    private func saveTokens(accessToken: String, refreshToken: String) async {
        await saveKeychainValue(key: accessTokenKey, value: accessToken)
        await saveKeychainValue(key: refreshTokenKey, value: refreshToken)
    }
    
    private func clearTokens() async {
        await deleteKeychainValue(key: accessTokenKey)
        await deleteKeychainValue(key: refreshTokenKey)
        await deleteKeychainValue(key: userKey)
        await deleteKeychainValue(key: "oauth_state")
    }
    
    private func saveUser(_ user: User) async {
        if let userData = try? JSONEncoder().encode(user) {
            await saveKeychainValue(key: userKey, value: String(data: userData, encoding: .utf8) ?? "")
        }
    }
    
    private func loadUser() async -> User? {
        guard let userString = await getKeychainValue(key: userKey),
              let userData = userString.data(using: .utf8),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            return nil
        }
        return user
    }
    
    // MARK: - Keychain Operations
    private func saveKeychainValue(key: String, value: String) async {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getKeychainValue(key: String) async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func deleteKeychainValue(key: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
        }
        
        Task {
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                await processAppleIDCredential(appleIDCredential)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            isLoading = false
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    errorMessage = nil // User cancelled, don't show error
                case .failed:
                    errorMessage = "Authentication failed"
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple"
                case .notHandled:
                    errorMessage = "Authentication not handled"
                case .unknown:
                    errorMessage = "Unknown authentication error"
                @unknown default:
                    errorMessage = "Authentication error occurred"
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Auth Response Model
private struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidResponse
    case oauthFailed(String)
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .oauthFailed(let message):
            return message
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        }
    }
}
