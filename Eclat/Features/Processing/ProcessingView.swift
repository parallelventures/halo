//
//  ProcessingView.swift
//  Eclat
//
//  AI Processing screen - Emotional loading experience
//  Refactored to be "INSANE" level: Calm, progressional, intentional.
//

import SwiftUI
import StoreKit

struct ProcessingView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var creditsService: CreditsService
    
    // Explicit simulation mode for Onboarding
    var isSimulation: Bool = false
    
    // States for animation
    @State private var currentPhaseIndex = 0
    @State private var isBreathing = false
    @State private var showCancelButton = true
    @State private var hasError = false
    @State private var errorMessage: String = ""
    @State private var needsSignIn = false
    @State private var navigateToResult = false
    @State private var showAIConsent = false
    
    // Dynamic Phases (Emotional progression)
    private let phases = [
        "Analyzing face shape...",
        "Adapting hairstyle...",
        "Refining details...",
        "Almost ready..."
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            // MARK: - AI Consent Overlay (full screen, above everything)
            if showAIConsent {
                AIConsentView(
                    onAccept: {
                        UserDefaults.standard.set(true, forKey: "has_accepted_ai_consent")
                        withAnimation { showAIConsent = false }
                        startExperience()
                    },
                    onDecline: {
                        withAnimation { showAIConsent = false }
                        appState.navigateTo(.home)
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // 1. Image with Awakening/Breathing Animation
                ZStack {
                    if let capturedImage = appState.capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 280, height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            // Breathing Scale Animation
                            .scaleEffect(isBreathing ? 1.015 : 1.0)
                            // Subtle Blur evolution (starts blurry, gets clearer or opposite?) 
                            // Request said: "Blur très léger qui diminue au fil du temps"
                            .blur(radius: isBreathing ? 0 : 2) // Subtle pulsation
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .opacity(isBreathing ? 1.0 : 0.92)
                            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isBreathing)
                    } else {
                        // Fallback skeleton
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 280, height: 380)
                    }
                }
                .padding(.bottom, 40)
                
                // 2. Text & Status (Emotional Copy)
                VStack(spacing: 12) {
                    // Main Title
                    Text(hasError ? "Oops!" : "Perfecting your look...")
                        .font(.eclat.displayMedium)
                        .foregroundColor(.white)
                    
                    // Dynamic Subtext / Error Message
                    if hasError {
                        Text(errorMessage.isEmpty ? "Something went wrong" : errorMessage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        // Try Again button OR Sign In button
                        if needsSignIn {
                            Button {
                                hasError = false
                                errorMessage = ""
                                needsSignIn = false
                                appState.showAuthSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle")
                                    Text("Sign In")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Color.white, in: Capsule())
                            }
                            .padding(.top, 16)
                        } else {
                            Button {
                                hasError = false
                                errorMessage = ""
                                appState.navigateTo(.home)
                                appState.showCameraSheet = true
                            } label: {
                                Text("Try again")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.white, in: Capsule())
                            }
                            .padding(.top, 16)
                        }
                    } else {
                        Text(phases[currentPhaseIndex])
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .animation(.smooth(duration: 0.5), value: currentPhaseIndex)
                            .id("phase-\(currentPhaseIndex)")
                            .transition(.opacity.combined(with: .move(edge: .bottom).animation(.easeInOut)))
                        
                        // Expectation Framing
                        Text("This may take a few seconds.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // 3. Stop Generation Button (Degraded)
                if !hasError {
                    Button {
                        handleCancel()
                    } label: {
                        Text("Stop generation")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                    }
                    .opacity(showCancelButton ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: showCancelButton)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            checkAIConsentAndStart()
        }

        .onChange(of: navigateToResult) { _, shouldNavigate in
            if shouldNavigate {
                appState.navigateTo(.result)
                
                // DISABLED automatic paywall opening. Users should click "Unlock" on the Result screen if needed.
                /*
                if isSimulation || !creditsService.hasLooks {
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                         if subscriptionManager.isSubscribed {
                             appState.navigateTo(.creditsPaywall)
                         } else {
                             appState.showPaywall()
                         }
                     }
                }
                */
            }
        }
    }
    
    // MARK: - Logic
    
    // MARK: - AI Consent Check (Remote-configurable)
    private func checkAIConsentAndStart() {
        let hasConsented = UserDefaults.standard.bool(forKey: "has_accepted_ai_consent")
        if hasConsented || isSimulation || appState.isSimulationMode {
            startExperience()
            return
        }
        
        // Check remote config — if table doesn't exist, defaults to showing consent
        Task {
            let shouldShow = await fetchConsentFlag()
            await MainActor.run {
                if shouldShow {
                    withAnimation { showAIConsent = true }
                } else {
                    startExperience()
                }
            }
        }
    }
    
    /// Fetch remote flag from Supabase app_config table
    /// Defaults to true (show consent) if fetch fails — safe for Apple review
    private func fetchConsentFlag() async -> Bool {
        do {
            let response = try await SupabaseService.shared.client
                .from("app_config")
                .select("value")
                .eq("key", value: "show_ai_consent")
                .single()
                .execute()
            
            let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            if let value = json?["value"] as? String {
                return value == "true"
            }
        } catch {
            print("⚠️ Failed to fetch consent flag, defaulting to show: \(error)")
        }
        return true // Default: show consent (safe for review)
    }
    
    private func startExperience() {
        // Start breathing animation
        isBreathing = true
        
        // Hide cancel button after a few seconds to protect the moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showCancelButton = false
        }
        
        // Start Phase Rotator
        startPhaseLoop()
        
        // Start Actual (or Simulated) Processing
        startProcessing()
    }
    

    
    private func startPhaseLoop() {
        // Rotate phases every 1.8s
        Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { timer in
            guard !navigateToResult && !hasError else {
                timer.invalidate()
                return
            }
            
            if currentPhaseIndex < phases.count - 1 {
                withAnimation {
                    currentPhaseIndex += 1
                }
                // Haptic subtle on change
                let impact = UIImpactFeedbackGenerator(style: .soft)
                impact.impactOccurred()
            }
        }
    }
    
    private func startProcessing() {
        Task {
            // 🚨 CRITICAL: Refresh JWT token before any API calls (tokens expire after 1 hour)
            let tokenRefreshed = await AuthService.shared.refreshSession()
            if tokenRefreshed {
                print("🔄 JWT token refreshed successfully")
            }
            
            // 🚨 CRITICAL FIX: Fetch fresh subscription status and balance
            await subscriptionManager.refreshCustomerInfo()
            if SupabaseService.shared.currentUser != nil {
                await creditsService.fetchBalance()
            }
            
            // Use subscriptionManager which combines subscription status + credits
            // 🚨 FIX: Also check creditsService.balance for credit pack users
            let canGenerate = subscriptionManager.hasLooks || creditsService.balance > 0
            
            // 🚨 DEBUG
            print("🚨 PROCESSING DEBUG:")
            print("   - subscriptionManager.currentTier = \(subscriptionManager.currentTier.displayName)")
            print("   - subscriptionManager.isSubscribed = \(subscriptionManager.isSubscribed)")
            print("   - subscriptionManager.hasLooks = \(subscriptionManager.hasLooks)")
            print("   - subscriptionManager.weeklyLooksRemaining = \(subscriptionManager.weeklyLooksRemaining)")
            print("   - creditsService.balance = \(creditsService.balance)")
            print("   - canGenerate = \(canGenerate)")
            print("   - isSimulation (prop) = \(isSimulation)")
            print("   - appState.isSimulationMode = \(appState.isSimulationMode)")
            
            // SIMULATION MODE: Only if explicitly requested
            let shouldSimulate = isSimulation || appState.isSimulationMode
            
            if shouldSimulate {
                print("⚠️ ENTERING SIMULATION MODE - Explicit simulation requested")
                
                try? await Task.sleep(nanoseconds: 4_500_000_000) // 4.5s
                
                await MainActor.run {
                    HapticManager.notification(.success)
                    navigateToResult = true
                }
                return
            }
            
            // Check if user can generate (subscriber OR has credits)
            if !canGenerate {
                // 🚨 SAFETY NET: If user just came from auth flow, try one more restore
                // This catches edge cases where RevenueCat didn't properly transfer the purchase
                print("⚠️ No access detected - attempting final restore before paywall...")
                await subscriptionManager.restorePurchases()
                
                // Re-check after restore (also check credits)
                let canGenerateAfterRestore = subscriptionManager.hasLooks || creditsService.balance > 0
                print("   - After restore: hasLooks = \(subscriptionManager.hasLooks), credits = \(creditsService.balance)")
                
                if !canGenerateAfterRestore {
                    print("❌ Still no access after restore and no credits - showing paywall")
                    await MainActor.run {
                        appState.showPaywall()
                    }
                    return
                }
                // If restore worked, continue with generation
                print("✅ Restore successful - proceeding with generation")
            }
            
            // 🚨 DAILY LIMIT CHECK (8/day) - Server-side for subscribers
            await creditsService.checkDailyLimitFromServer()
            
            // Check if we should block or allow overdraft
            if creditsService.hasReachedDailyLimit {
                let hasCreditsToSpend = creditsService.balance > 0
                
                if hasCreditsToSpend {
                    print("⚠️ Daily limit reached but user has \(creditsService.balance) credits. Allowing OVERDRAFT generation.")
                    // Do NOT return. Fall through to credit spending logic.
                } else {
                    print("⛔️ DAILY LIMIT REACHED: \(creditsService.dailyGenerationCount)/8 and NO credits.")
                    await MainActor.run {
                        appState.showDailyLimitReached = true
                        appState.dailyLimitResetTime = creditsService.timeUntilReset
                    }
                    return
                }
            }
            
            // REAL GENERATION
            print("🚀 Starting Real Generation")
            
            guard let capturedImage = appState.capturedImage,
                  let hairstyle = appState.selectedHairstyle else {
                await MainActor.run { hasError = true }
                return
            }
            
            do {
                // Generate prompt
                var prompt: String
                if let nanoBananaPrompt = NanoBananaWomenHairOnlyPrompts.prompt(for: hairstyle.name) {
                    prompt = nanoBananaPrompt.json
                } else {
                    prompt = hairstyle.prompt
                }
                
                // INJECT COLOR if selected
                if let color = appState.selectedColor {
                    print("🎨 Injecting color: \(color.name)")
                    
                    if prompt.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") {
                        var jsonString = String(prompt.trimmingCharacters(in: .whitespacesAndNewlines).dropLast())
                        jsonString += ", \"color\": \"\(color.promptModifier)\" }"
                        prompt = jsonString
                    } else {
                        prompt += ", \(color.promptModifier)"
                    }
                }
                
                // ⚡️ TIER-BASED ACCESS CONTROL
                // Free + credits = spend 1 credit per generation
                // Creator = 20/week (tracked by recordLookUsed)
                // Atelier = Unlimited
                
                let tier = subscriptionManager.currentTier
                var shouldSpendCredit = false
                
                switch tier {
                case .atelier:
                    print("✨ ATELIER — unlimited generation")
                    
                case .creator:
                    if subscriptionManager.weeklyLooksRemaining <= 0 {
                        // Weekly limit reached — can still generate if they have credits
                        if creditsService.balance > 0 {
                            print("🎨 CREATOR weekly limit reached but has \(creditsService.balance) credits — using credit")
                            shouldSpendCredit = true
                        } else {
                            print("⛔️ CREATOR weekly limit reached: \(subscriptionManager.weeklyLooksUsed)/20")
                            throw NSError(domain: "Halo", code: 429, userInfo: [NSLocalizedDescriptionKey: "Weekly look limit reached. Upgrade to Atelier for unlimited looks!"])
                        }
                    } else {
                        print("🎨 CREATOR — \(subscriptionManager.weeklyLooksRemaining) looks remaining this week")
                    }
                    
                case .free:
                    if creditsService.balance > 0 {
                        print("💎 FREE tier with \(creditsService.balance) credits — spending 1 credit")
                        shouldSpendCredit = true
                    } else {
                        print("⛔️ FREE tier — no credits, no generation allowed")
                        throw NSError(domain: "Halo", code: 402, userInfo: [NSLocalizedDescriptionKey: "Upgrade to Creator or Atelier to generate looks!"])
                    }
                }
                
                // 🚨 SPEND CREDIT: Atomically decrement on server BEFORE generation
                if shouldSpendCredit {
                    let spent = await creditsService.spendCredit()
                    if !spent {
                        print("❌ Failed to spend credit (insufficient or server error)")
                        throw NSError(domain: "Halo", code: 402, userInfo: [NSLocalizedDescriptionKey: "No credits available. Get more Looks!"])
                    }
                    print("✅ Credit spent! Remaining: \(creditsService.balance)")
                }
                
                // Launch generation
                let generated = try await GeminiAPIService.shared.generateHairstyle(
                    from: capturedImage,
                    prompt: prompt
                )
                
                await MainActor.run {
                    appState.setGeneratedImage(generated)
                    
                    // 📊 Record look used (for Creator weekly tracking)
                    subscriptionManager.recordLookUsed()
                    
                    // 📊 Record generation for daily limit tracking
                    creditsService.recordGeneration()
                    
                    // Final haptic
                    HapticManager.notification(.success)
                    
                    // Force UI to "Almost ready..." for a moment if it hasn't reached it
                    withAnimation {
                        currentPhaseIndex = phases.count - 1
                    }
                    
                    navigateToResult = true
                }
                
            } catch {
                await MainActor.run {
                    hasError = true
                    HapticManager.error()
                    
                    // Parse error for user-friendly message
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("no content") || errorString.contains("no image") || errorString.contains("no parts") {
                        errorMessage = "The AI couldn't generate this style. Try a different photo or hairstyle."
                    } else if errorString.contains("safety") || errorString.contains("blocked") {
                        errorMessage = "This photo couldn't be processed. Please try a different photo."
                    } else if errorString.contains("sign in") || errorString.contains("unauthorized") || errorString.contains("invalid jwt") {
                        errorMessage = "Please sign in to generate hairstyles."
                        needsSignIn = true
                    } else if errorString.contains("credits") || errorString.contains("insufficient") {
                        errorMessage = "You need more Looks to generate. Get some in the shop!"
                    } else if errorString.contains("limit") {
                        errorMessage = "Daily limit reached. Come back tomorrow or get more Looks!"
                    } else if errorString.contains("network") || errorString.contains("connection") {
                        errorMessage = "Connection issue. Check your internet and try again."
                    } else {
                        errorMessage = "Something went wrong. Please try again."
                        print("❌ Unhandled error: \(error.localizedDescription)")
                    }
                    
                    appState.errorMessage = errorMessage
                    // Don't auto-navigate - let user see error and tap "Try again"
                }
            }
        }
    }
    
    private func handleCancel() {
        HapticManager.light()
        appState.reset()
        appState.navigateTo(.home)
        appState.showCameraSheet = true
    }
}

#Preview {
    ProcessingView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(CreditsService.shared)
}
