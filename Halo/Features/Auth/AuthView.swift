//
//  AuthView.swift
//  Halo
//
//  Premium authentication screen shown after successful payment
//

import SwiftUI

struct AuthView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        ZStack {
            // Aurora background
            AnimatedDarkGradient()
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Headline
                VStack(spacing: 16) {
                    Text("One Last Step")
                        .font(.custom("Agrandir-NarrowBold", size: 48))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Create your account to unlock your transformation")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
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
                    
                    // Google Sign In (placeholder - needs Google SDK)
                    Button {
                        // TODO: Implement Google Sign In
                    } label: {
                        HStack(spacing: 12) {
                            Image("google-logo") // Use asset image
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
                    .disabled(true) // Disabled until implemented
                    .opacity(0.5)
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
            // Navigate to result when authenticated
            if case .authenticated = newState {
                HapticManager.success()
                appState.navigateTo(.result)
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
