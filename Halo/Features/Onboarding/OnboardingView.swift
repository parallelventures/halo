//
//  OnboardingView.swift
//  Halo
//
//  Clean onboarding flow with Sign in with Apple
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

// MARK: - Onboarding Step
struct OnboardingStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
}

extension OnboardingStep {
    static let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "camera.fill",
            title: "Snap a Selfie",
            subtitle: "Take a quick photo or choose from your gallery",
            gradient: [Color.theme.accentPrimary, Color.theme.accentSecondary]
        ),
        OnboardingStep(
            icon: "wand.and.stars",
            title: "Choose Your Style",
            subtitle: "Browse trending hairstyles curated by experts",
            gradient: [Color.theme.accentSecondary, Color.theme.accentTertiary]
        ),
        OnboardingStep(
            icon: "sparkles",
            title: "See the Magic",
            subtitle: "AI transforms your look in seconds",
            gradient: [Color.theme.accentTertiary, Color.theme.accentPrimary]
        )
    ]
}

// MARK: - Onboarding View
struct OnboardingView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var authService = AuthService.shared
    @State private var currentPage = 0
    @State private var isVisible = false
    
    private let steps = OnboardingStep.steps
    
    var body: some View {
        ZStack {
            // Aurora background
            AnimatedDarkGradient()
            
            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    Button("Skip") {
                        HapticManager.light()
                        appState.completeOnboarding()
                    }
                    .font(.halo.labelMedium)
                    .foregroundColor(.theme.textSecondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                
                Spacer()
                
                // Content
                VStack(spacing: Spacing.xl) {
                    // Icon
                    Circle()
                        .fill(Color.theme.glassFill)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(colors: steps[currentPage].gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.5
                                )
                        )
                        .overlay(
                            Image(systemName: steps[currentPage].icon)
                                .font(.system(size: 40, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(colors: steps[currentPage].gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        )
                    
                    VStack(spacing: Spacing.sm) {
                        Text(steps[currentPage].title)
                            .font(.halo.displayMedium)
                            .foregroundColor(.theme.textPrimary)
                        
                        Text(steps[currentPage].subtitle)
                            .font(.halo.bodyLarge)
                            .foregroundColor(.theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                    }
                }
                .opacity(isVisible ? 1 : 0)
                .animation(.haloSmooth, value: currentPage)
                
                Spacer()
                
                // Page indicators
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.theme.accentPrimary : Color.theme.textTertiary)
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.haloSpring, value: currentPage)
                    }
                }
                
                Spacer()
                    .frame(height: Spacing.xl)
                
                // CTA
                VStack(spacing: Spacing.md) {
                    if currentPage == steps.count - 1 {
                        // Final page - show auth options
                        authButtons
                    } else {
                        // Regular next button
                        HaloCTAButton("Next") {
                            withAnimation(.haloSmooth) {
                                currentPage += 1
                            }
                        }
                    }
                    
                    if currentPage == steps.count - 1 {
                        Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                            .font(.halo.caption)
                            .foregroundColor(.theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
        .onAppear {
            withAnimation(.haloSmooth(delay: 0.1)) {
                isVisible = true
            }
        }
        .onChange(of: authService.authState) { _, newValue in
            if case .authenticated = newValue {
                appState.completeOnboarding()
            }
        }
        .alert("Error", isPresented: .constant(authService.errorMessage != nil)) {
            Button("OK") { authService.errorMessage = nil }
        } message: {
            Text(authService.errorMessage ?? "")
        }
    }
    
    // MARK: - Auth Buttons
    private var authButtons: some View {
        VStack(spacing: 12) {
            // Sign in with Apple
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { _ in }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .cornerRadius(25)
            .overlay(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.shared.buttonPress()
                        authService.signInWithApple()
                    }
            )
            .disabled(authService.isLoading)
            
            // Sign in with Google (native SDK)
            GoogleSignInButton {
                HapticManager.shared.buttonPress()
            }
            .disabled(authService.isLoading)
            
            if authService.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 8)
            }
        }
        .opacity(authService.isLoading ? 0.6 : 1)
    }
}

// MARK: - Google Sign In Button (requires GoogleSignIn SDK)
struct GoogleSignInButton: View {
    let action: () -> Void
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Button {
            action()
            signInWithGoogle()
        } label: {
            HStack(spacing: 8) {
                // Google "G" logo
                Image("google")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.white, in: RoundedRectangle(cornerRadius: 25))
        }
    }
    
    private func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            authService.errorMessage = "Could not find root view controller"
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                Task { @MainActor in
                    self.authService.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                Task { @MainActor in
                    self.authService.errorMessage = "Failed to get Google credentials"
                }
                return
            }
            
            Task {
                do {
                    try await self.authService.authenticateWithGoogleToken(
                        idToken: idToken,
                        accessToken: user.accessToken.tokenString
                    )
                } catch {
                    await MainActor.run {
                        self.authService.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
