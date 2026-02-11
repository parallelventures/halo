//
//  OnboardingProcessingView.swift
//  Eclat
//
//  Fake processing view for onboarding flow
//  Shows artificial progress, triggers review prompt, then shows paywall
//

import SwiftUI
import StoreKit

struct OnboardingProcessingView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
    
    // Progress state
    @State private var progress: CGFloat = 0.0
    @State private var currentPhaseIndex = 0
    @State private var isBreathing = false
    @State private var hasRequestedReview = false
    @State private var progressComplete = false
    
    // Phase messages (emotional progression)
    private let phases = [
        "Analyzing your features...",
        "Matching your face shape...",
        "Adapting hairstyle...",
        "Perfecting details...",
        "Almost ready..."
    ]
    
    // Timing constants
    private let totalDuration: Double = 7.0 // Increased for review interaction
    private let reviewTriggerProgress: CGFloat = 0.70 // Trigger earlier (70%)
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // 1. Image with Awakening/Breathing Animation
                // Clean Glass Card Design (No border, No shimmer)
                ZStack {
                    if let capturedImage = appState.capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 280, height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            // Breathing Scale Animation
                            .scaleEffect(isBreathing ? 1.015 : 1.0)
                            // Subtle Blur evolution
                            .blur(radius: max(0, 3 - (progress * 4)))
                            // Simple shadow instead of border/glow
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    } else {
                        // Fallback skeleton
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 280, height: 380)
                    }
                }
                .padding(.bottom, 40)
                // Remove all overlays (border, shimmer)
                
                // 2. Text & Status
                VStack(spacing: 16) {
                    // Main Title
                    Text("Creating your look...")
                        .font(.eclat.displayMedium)
                        .foregroundColor(.white)
                    
                    // Dynamic phase text
                    Text(phases[currentPhaseIndex])
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .animation(.easeInOut(duration: 0.5), value: currentPhaseIndex)
                        .id("phase-\(currentPhaseIndex)")
                    
                    // Progress Bar REMOVED
                }
                
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startFakeProgress()
        }
        // Listen for global paywall dismissal
        .onChange(of: appState.showPaywallSheet) { _, isPresented in
            // If paywall WAS presented and is NOW dismissed (false)
            if !isPresented {
                // Only handle post-paywall if we finished our progress flow
                // This prevents issues if paywall was closed for other reasons
                if progressComplete {
                    handlePostPaywall()
                }
            }
        }
        // Local Paywall Presentation for Onboarding Flow
        // Using Variant A (Creator/Visual Paywall)
        .fullScreenCover(isPresented: $appState.showPaywallSheet) {
            VariantAPaywallView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
    }
    
    // MARK: - Fake Progress Logic
    
    private func startFakeProgress() {
        // Start breathing animation
        isBreathing = true
        
        // Ensure we have fresh info
        Task {
            await subscriptionManager.refreshCustomerInfo()
        }
        
        // Animate progress over time
        let steps = 100
        let stepDuration = totalDuration / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                
                // Linear progress for internal logic
                progress = CGFloat(i) / CGFloat(steps)
                
                // Update phase
                let phaseIndex = min(phases.count - 1, Int(progress * CGFloat(phases.count)))
                if phaseIndex != currentPhaseIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPhaseIndex = phaseIndex
                    }
                    HapticManager.light()
                }
                
                // Trigger review at 70%
                if progress >= reviewTriggerProgress && !hasRequestedReview {
                    hasRequestedReview = true
                    triggerReviewRequest()
                }
                
                // Complete at 100%
                if i == steps {
                    completeProgress()
                }
            }
        }
    }
    
    private func triggerReviewRequest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            requestReview()
            HapticManager.notification(.success)
        }
    }
    
    private func completeProgress() {
        progressComplete = true
        HapticManager.notification(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // FORCE PAYWALL SHOW unless strictly subscribed
            // Debug print to be sure
            print("🔒 Fake Processing Complete. Subscribed: \(subscriptionManager.isSubscribed)")
            
            if subscriptionManager.isSubscribed {
                handlePostPaywall()
            } else {
                appState.showPaywall()
            }
        }
    }
    
    private func handlePostPaywall() {
        // Called when global paywall is dismissed OR skipped
        print("🚪 Handle Post Paywall -> Navigate to Auth")
        appState.hasCompletedOnboarding = true
        
        // Prevent double navigation if paywall already navigated us
        if appState.currentScreen != .auth {
            appState.navigateTo(.auth)
        }
        
        // If this view is presented as a cover, dismiss it
        dismiss()
    }
}

#Preview {
    OnboardingProcessingView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
}
