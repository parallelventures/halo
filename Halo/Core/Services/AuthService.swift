//
//  AuthService.swift
//  Halo
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
final class AuthService: NSObject, ObservableObject {
    
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
        controller.performRequests()
        
        isLoading = true
    }
    
    // MARK: - Send Apple Token to Supabase
    private func authenticateWithSupabase(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=id_token")!
        
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
        
        // Sync with RevenueCat
        Task {
            await SubscriptionManager.shared.login(userID: userId)
        }
        
        authState = .authenticated(userId: userId)
    }
    
    // MARK: - Sign Out
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
        authState = .unauthenticated
    }
    
    // MARK: - Get Access Token
    func getAccessToken() -> String? {
        UserDefaults.standard.string(forKey: "supabase_access_token")
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
              let rootViewController = windowScene.windows.first?.rootViewController else {
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
        
        // Sync with RevenueCat
        await SubscriptionManager.shared.login(userID: userId)
        
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
