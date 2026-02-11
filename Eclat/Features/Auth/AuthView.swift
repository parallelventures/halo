//
//  AuthView.swift
//  Eclat
//
//  Premium authentication screen shown after successful payment
//

import SwiftUI
import GoogleSignIn

struct AuthView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var creditsService: CreditsService
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        ZStack {
            // Aurora background
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Headline
                VStack(spacing: 16) {
                    Text("Save your transformation")
                        .font(.custom("GTAlpinaTrial-CondensedThin", size: 48))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Create an account to save your lifetime credits and generated styles forever.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Auth buttons
                VStack(spacing: 16) {
                    // Apple Sign In - Using native button (white style)
                    Button {
                        authService.signInWithApple()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Continue with Apple")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white, in: Capsule())
                    }
                    .disabled(authService.isLoading)
                    
                    // Google Sign In
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            Image("google")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.black, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(authService.isLoading)
                }
                .padding(.horizontal, 32)
                
                // Privacy & Terms
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                    
                    HStack(spacing: 8) {
                        Button("Terms of Service") {
                            openURL("https://parallelventures.eu/terms-of-use/")
                        }
                        Text("•")
                        Button("Privacy Policy") {
                            openURL("https://parallelventures.eu/privacy-policy/")
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
            }
            
            // Loading overlay
            if authService.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .alert("Authentication Error", isPresented: .constant(authService.errorMessage != nil)) {
            Button("OK") { authService.errorMessage = nil }
        } message: {
            Text(authService.errorMessage ?? "")
        }
        .onChange(of: authService.authState) { _, newState in
            // Navigate based on state when authenticated
            if case .authenticated = newState {
                HapticManager.success()
                print("🔐 Auth SUCCESS - Starting sync before navigation")
                
                // 1. Critical State Updates (Synchronous)
                appState.isSimulationMode = false
                
                // 2. Sync credits and navigate
                Task {
                    print("🔄 Syncing credits...")
                    
                    // RevenueCat handles entitlements automatically via the SDK.
                    // Just sync credits balance from Supabase.
                    await CreditsService.shared.syncAfterAuth()
                    await CreditsService.shared.fetchBalance()
                    
                    print("✅ Sync completed - isSubscribed: \(SubscriptionManager.shared.isSubscribed), hasLooks: \(SubscriptionManager.shared.hasLooks)")
                    
                    // 3. Navigate to Home
                    await MainActor.run {
                        appState.capturedImage = nil
                        appState.selectedHairstyle = nil
                        print("🏠 Auth complete - going Home")
                        appState.navigateTo(.home)
                    }
                }
            }
        }
    }
    
    // MARK: - Sync Generation to Supabase
    private func syncPendingGeneration() {
        print("🔒 AuthView.syncPendingGeneration called")
        print("   - capturedImage: \(appState.capturedImage != nil)")
        print("   - generatedImage: \(appState.generatedImage != nil)")
        print("   - selectedHairstyle: \(appState.selectedHairstyle?.name ?? "nil")")
        print("   - currentUser: \(SupabaseService.shared.currentUser?.id.uuidString ?? "nil")")
        
        // If we have a generated image and selected hairstyle, sync it
        guard let capturedImage = appState.capturedImage,
              let generatedImage = appState.generatedImage,
              let hairstyle = appState.selectedHairstyle else {
            print("⚠️ Cannot sync - missing required data for generation")
            return
        }
        
        print("✅ All data present, starting Supabase sync...")
        
        // Sync in background
        Task {
            if let generation = await GenerationService.shared.createGeneration(
                originalImage: capturedImage,
                styleName: hairstyle.name,
                styleCategory: hairstyle.category.rawValue,
                stylePrompt: nil // Use optimized prompt from service
            ) {
                print("✅ Generation record created: \(generation.id)")
                let success = await GenerationService.shared.updateGenerationResult(
                    generationId: generation.id,
                    generatedImage: generatedImage,
                    processingTimeMs: 0 // We don't have the timing anymore
                )
                if success {
                    print("✅ Generation synced to Supabase successfully!")
                } else {
                    print("❌ Failed to update generation result in Supabase")
                }
            } else {
                print("❌ Failed to create generation record in Supabase")
            }
        }
    }
    
    
    // MARK: - Google Sign In Helper
    private func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            authService.errorMessage = "Could not find root view controller"
            return
        }
        
        // Get Google Client ID from Supabase config or Info.plist
        // You need to add GIDClientID to Info.plist with your Google Client ID
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            authService.errorMessage = "Google Client ID not configured"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                Task { @MainActor in
                    authService.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                Task { @MainActor in
                    authService.errorMessage = "Failed to get Google ID token"
                }
                return
            }
            
            // Authenticate with Supabase using Google token
            Task {
                do {
                    try await authService.authenticateWithGoogleToken(
                        idToken: idToken,
                        accessToken: user.accessToken.tokenString
                    )
                } catch {
                    await MainActor.run {
                        authService.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
}
