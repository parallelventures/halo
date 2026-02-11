//
//  AuthService.swift
//  Eclat
//
//  Authentication service with Sign in with Apple
//

import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Auth State
enum AuthState: Equatable {
    case unknown
    case unauthenticated
    case authenticated(userId: String)
}

// MARK: - Auth Service
@MainActor
final class AuthService: NSObject, ObservableObject, ASAuthorizationControllerPresentationContextProviding {
    
    static let shared = AuthService()
    
    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private var currentNonce: String?
    private let session = URLSession.shared
    
    var userId: String? {
        if case .authenticated(let id) = authState {
            return id
        }
        return nil
    }
    
    var isAuthenticated: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }
    
    var isAnonymous: Bool {
        UserDefaults.standard.bool(forKey: "is_anonymous_session")
    }
    
    // MARK: - Init
    override init() {
        super.init()
        checkExistingSession()
    }
    
    // MARK: - Check Existing Session
    private func checkExistingSession() {
        if let token = UserDefaults.standard.string(forKey: "supabase_access_token"),
           let userId = UserDefaults.standard.string(forKey: "supabase_user_id"),
           !token.isEmpty {
            authState = .authenticated(userId: userId)
        } else {
            authState = .unauthenticated
        }
    }
    
    // MARK: - Sign in with Apple
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        
        isLoading = true
    }
    
    // MARK: - Send Apple Token to Supabase
    private func authenticateWithSupabase(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=id_token") else {
            throw AuthError.serverError("Invalid configuration URL")
        }
        
        var body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce
        ]
        
        // Add name if available (first sign in only)
        if let fullName = fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                body["options"] = ["data": ["full_name": name]]
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["error_description"] as? String ?? errorJson["msg"] as? String {
                throw AuthError.serverError(message)
            }
            throw AuthError.serverError("Authentication failed")
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let user = json["user"] as? [String: Any],
              let userId = user["id"] as? String else {
            throw AuthError.invalidResponse
        }
        
        // Save session
        UserDefaults.standard.set(accessToken, forKey: "supabase_access_token")
        UserDefaults.standard.set(userId, forKey: "supabase_user_id")
        
        if let refreshToken = json["refresh_token"] as? String {
            UserDefaults.standard.set(refreshToken, forKey: "supabase_refresh_token")
        }
        
        // Sync with RevenueCat - MUST AWAIT to ensure aliasing completes
        // This transfers the anonymous purchase to the new authenticated user
        await SubscriptionManager.shared.login(userID: userId)
        
        // 🚨 CRITICAL: Create profile and entitlements in database
        let email = (user["email"] as? String)
        var fullName: String? = nil
        if let userData = user["user_metadata"] as? [String: Any] {
            fullName = userData["full_name"] as? String
        }
        await ensureProfileAndEntitlements(userId: userId, email: email, fullName: fullName)
        
        // Sync onboarding data to Supabase
        Task {
            await OnboardingDataService.shared.syncToSupabase()
        }
        
        // Track with TikTok SDK
        TikTokService.shared.identifyUser(userId: userId, email: email)
        TikTokService.shared.trackRegistration(method: "apple")
        
        // No longer anonymous
        UserDefaults.standard.set(false, forKey: "is_anonymous_session")
        
        print("🔐🔐🔐 AUTH SUCCESS - Setting authState to authenticated")
        authState = .authenticated(userId: userId)
        
        // Post notification to navigate (backup for onChange)
        NotificationCenter.default.post(name: .authSuccess, object: nil)
    }
    
    // MARK: - Sign Out
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
        authState = .unauthenticated
        Task {
            await SubscriptionManager.shared.logout()
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount() async {
        // En production, il faudrait appeler une Cloud Function pour supprimer l'utilisateur de Auth
        // Ici on supprime les données locales et on déconnecte
        signOut()
        HapticManager.success()
    }
    
    // MARK: - Ensure Profile Exists
    /// Creates/updates the user's profile in Supabase for analytics.
    /// Also ensures entitlements row exists via server-side Edge Function.
    func ensureProfileAndEntitlements(userId: String, email: String? = nil, fullName: String? = nil) async {
        print("🔐 Ensuring profile exists for user: \(userId)")
        
        let supabase = SupabaseService.shared.client
        
        // 1. Create/Update Profile (for analytics only)
        do {
            let profileData: [String: Any] = [
                "id": userId,
                "email": email ?? NSNull(),
                "full_name": fullName ?? NSNull(),
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            try await supabase
                .from("profiles")
                .upsert(profileData)
                .execute()
            
            print("✅ Profile ensured for user: \(userId)")
        } catch {
            print("⚠️ Failed to ensure profile: \(error.localizedDescription)")
        }
        
        // 2. 🚨 CRITICAL: Call ensure-entitlement Edge Function
        // This creates the entitlements row if it doesn't exist AND
        // verifies with RevenueCat server-side to recover any missed purchases.
        // Without this, entitlements only exist if the RC webhook fired correctly.
        do {
            let _ = try await SupabaseService.shared.client.functions.invoke("ensure-entitlement", body: [:])
            print("✅ Entitlement row ensured via Edge Function")
        } catch {
            print("⚠️ ensure-entitlement call failed (non-blocking): \(error.localizedDescription)")
        }
        
        // 3. Sync credits from local cache to server (in case of pending credits)
        await CreditsService.shared.syncAfterAuth()
        
        print("🔐 Profile setup complete for: \(userId)")
    }
    
    // MARK: - Get Access Token
    func getAccessToken() -> String? {
        UserDefaults.standard.string(forKey: "supabase_access_token")
    }
    
    // MARK: - Refresh Session
    /// Refreshes the auth session with retry logic to prevent accidental disconnections
    func refreshSession() async -> Bool {
        guard let refreshToken = UserDefaults.standard.string(forKey: "supabase_refresh_token") else {
            print("❌ No refresh token available")
            return false
        }
        
        // 🚨 CRITICAL: Retry up to 3 times before giving up
        // This prevents accidental disconnection due to temporary network issues
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let result = try await attemptTokenRefresh(refreshToken: refreshToken)
                if result {
                    return true
                }
            } catch RefreshError.invalidToken {
                // Token is truly invalid (401/403), no point retrying
                print("❌ Refresh token is invalid - signing out")
                signOut()
                return false
            } catch {
                lastError = error
                print("⚠️ Refresh attempt \(attempt)/\(maxRetries) failed: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // Exponential backoff: 0.5s, 1s, 2s
                    let delay = UInt64(pow(2.0, Double(attempt - 1)) * 500_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }
        
        // All retries failed - but don't sign out, just return false
        // The user can still use cached data and try again later
        print("❌ All \(maxRetries) refresh attempts failed. Error: \(lastError?.localizedDescription ?? "unknown")")
        print("ℹ️ NOT signing out - user may retry later when connection is better")
        return false
    }
    
    private enum RefreshError: Error {
        case invalidToken
        case networkError
        case unknownError
    }
    
    private func attemptTokenRefresh(refreshToken: String) async throws -> Bool {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=refresh_token")!
        
        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RefreshError.unknownError
        }
        
        // Check for auth errors (token truly invalid)
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw RefreshError.invalidToken
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ Token refresh failed with status: \(httpResponse.statusCode)")
            throw RefreshError.networkError
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let accessToken = json["access_token"] as? String,
           let user = json["user"] as? [String: Any],
           let userId = user["id"] as? String {
            
            // Update tokens
            UserDefaults.standard.set(accessToken, forKey: "supabase_access_token")
            UserDefaults.standard.set(userId, forKey: "supabase_user_id")
            
            // 🚨 DEBUG: Log new token info
            print("🔄 New access token saved:")
            print("   - Token parts: \(accessToken.split(separator: ".").count)")
            print("   - Token prefix: \(String(accessToken.prefix(50)))...")
            
            if let newRefreshToken = json["refresh_token"] as? String {
                UserDefaults.standard.set(newRefreshToken, forKey: "supabase_refresh_token")
            }
            
            await MainActor.run {
                self.authState = .authenticated(userId: userId)
            }
            
            print("✅ Session refreshed successfully")
            return true
        }
        
        return false
    }
    
    // MARK: - Sign in Anonymously
    func signInAnonymously() async {
        // If already authenticated, do nothing
        if isAuthenticated { return }
        
        isLoading = true
        
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/signup")!
        
        // Create random credentials for anonymous user
        let email = "\(UUID().uuidString)@anonymous.eclat.app"
        let password = UUID().uuidString
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": ["is_anonymous": true]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ Anonymous sign in failed")
                isLoading = false
                return
            }
            
            // Parse response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String,
               let user = json["user"] as? [String: Any],
               let userId = user["id"] as? String {
                
                // Save session
                UserDefaults.standard.set(accessToken, forKey: "supabase_access_token")
                UserDefaults.standard.set(userId, forKey: "supabase_user_id")
                
                if let refreshToken = json["refresh_token"] as? String {
                    UserDefaults.standard.set(refreshToken, forKey: "supabase_refresh_token")
                }
                
                self.authState = .authenticated(userId: userId)
                self.isLoading = false
                
                // Mark as anonymous
                UserDefaults.standard.set(true, forKey: "is_anonymous_session")
                
                print("✅ Signed in anonymously with ID: \(userId)")
                
                // Sync with RevenueCat
                await SubscriptionManager.shared.login(userID: userId)
                
                // 🚨 CRITICAL: Create profile and entitlements even for anonymous users
                // This ensures they have records if they purchase before signing in
                await ensureProfileAndEntitlements(userId: userId, email: nil, fullName: nil)
            }
        } catch {
            print("❌ Anonymous sign in error: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Sign in with Google (Native SDK)
    func signInWithGoogle() {
        isLoading = true
        
        // Get the GoogleSignIn instance
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let _ = windowScene.windows.first?.rootViewController else {
            isLoading = false
            errorMessage = "Could not find root view controller"
            return
        }
        
        // Import GoogleSignIn at runtime - requires adding the package
        // The actual sign-in is handled in the AppDelegate or via the GIDSignIn shared instance
        
        // For now, we'll use the ID token approach
        // You need to call GIDSignIn.sharedInstance.signIn(withPresenting:) from the view
        
        // This will be called from the view with the actual GoogleSignIn SDK
        isLoading = false
        errorMessage = "Please use the GoogleSignIn SDK button"
    }
    
    // MARK: - Authenticate with Google ID Token
    func authenticateWithGoogleToken(idToken: String, accessToken: String?) async throws {
        isLoading = true
        
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=id_token")!
        
        var body: [String: Any] = [
            "provider": "google",
            "id_token": idToken
        ]
        
        if let accessToken = accessToken {
            body["access_token"] = accessToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            isLoading = false
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["error_description"] as? String ?? errorJson["msg"] as? String ?? errorJson["error"] as? String {
                isLoading = false
                throw AuthError.serverError(message)
            }
            isLoading = false
            throw AuthError.serverError("Authentication failed")
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let supabaseAccessToken = json["access_token"] as? String,
              let user = json["user"] as? [String: Any],
              let userId = user["id"] as? String else {
            isLoading = false
            throw AuthError.invalidResponse
        }
        
        // Save session
        UserDefaults.standard.set(supabaseAccessToken, forKey: "supabase_access_token")
        UserDefaults.standard.set(userId, forKey: "supabase_user_id")
        
        if let refreshToken = json["refresh_token"] as? String {
            UserDefaults.standard.set(refreshToken, forKey: "supabase_refresh_token")
        }
        
        // Sync with RevenueCat - Ensure we await this!
        await SubscriptionManager.shared.login(userID: userId)
        
        // 🚨 CRITICAL: Create profile and entitlements in database
        let email = (user["email"] as? String)
        var fullName: String? = nil
        if let userData = user["user_metadata"] as? [String: Any] {
            fullName = userData["full_name"] as? String ?? userData["name"] as? String
        }
        await ensureProfileAndEntitlements(userId: userId, email: email, fullName: fullName)
        
        // Sync onboarding data to Supabase
        await OnboardingDataService.shared.syncToSupabase()
        
        // Track with TikTok SDK
        TikTokService.shared.identifyUser(userId: userId, email: email)
        TikTokService.shared.trackRegistration(method: "google")
        
        // No longer anonymous
        UserDefaults.standard.set(false, forKey: "is_anonymous_session")
        
        authState = .authenticated(userId: userId)
        isLoading = false
        HapticManager.success()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthService: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let idTokenData = appleCredential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            isLoading = false
            errorMessage = "Failed to get Apple credentials"
            return
        }
        
        Task {
            do {
                try await authenticateWithSupabase(
                    idToken: idToken,
                    nonce: nonce,
                    fullName: appleCredential.fullName
                )
                isLoading = false
                HapticManager.success()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                HapticManager.error()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthService {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Find the best window scene to present on (Key fix for iPad)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        }
    }
}
