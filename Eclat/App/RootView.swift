//
//  RootView.swift
//  Eclat
//
//  Root navigation controller - manages app flow based on state
//

import SwiftUI

struct RootView: View {
    
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var creditsService: CreditsService
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Global background - covers safe areas
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            // Content based on app state
            Group {
                switch appState.currentScreen {
                case .splash:
                    SplashView()
                        .transition(.opacity)
                        .task {
                            await appState.performBootSequence()
                        }
                    
                case .onboarding:
                    OnboardingView()
                        .transition(.opacity)
                    
                case .processing:
                    // 🚨 CRITICAL: Use session ID to force NEW instance when navigating
                    // This ensures startProcessing() runs fresh after auth with updated credits
                    ProcessingView()
                        .id(appState.processingSessionId) // Changes on each navigateTo(.processing)
                        .transition(.opacity)
                    
                case .result:
                    ResultView()
                        .transition(.opacity)
                    
                case .paywall:
                    // Paywall is shown as fullScreenCover
                    ResultView()
                        .transition(.opacity)
                
                case .creditsPaywall:
                     // Top-up Paywall is shown as fullScreenCover
                     HomeView() 
                        .transition(.opacity)
                    
                case .auth:
                    AuthView()
                        .transition(.opacity)
                    
                case .home:
                    HomeView()
                        .transition(.opacity)
                        .onAppear {
                            // Request notification permission reliably
                            NotificationManager.shared.requestPermission()
                        }
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.currentScreen)
        
        // MARK: - Global Sheets & Covers
        
        // 1. Paywall Sheet (Global) - Only if NOT in Onboarding
        .fullScreenCover(isPresented: Binding(
            get: { appState.showPaywallSheet && appState.currentScreen != .onboarding },
            set: { appState.showPaywallSheet = $0 }
        )) {
            VariantAPaywallView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        
        // 1b. Segmented Paywall (Server-driven, for existing users / credits refill)
        .fullScreenCover(isPresented: $appState.showSegmentedPaywall) {
            if let decision = appState.currentOfferDecision,
               let offerKey = decision.offerKey,
               let surface = decision.surface {
                SegmentedPaywallView(
                    offerKey: offerKey,
                    surface: surface,
                    copyVariant: decision.copyVariant
                )
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .environmentObject(creditsService)
            }
        }
        
        // 2. Post-Paywall Flow
        .fullScreenCover(isPresented: $appState.showPostPaywallOnboarding) {
             OnboardingView()
                 .environmentObject(appState)
        }
        
        // 3. Top-up Credits Paywall
        .fullScreenCover(isPresented: Binding(
            get: { appState.currentScreen == .creditsPaywall },
            set: { isPresented in
                if !isPresented && appState.currentScreen == .creditsPaywall {
                    appState.navigateTo(.home)
                }
            }
        )) {
            CreditsPaywallView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .environmentObject(creditsService)
        }
        
        // 4. Camera Sheet
        .sheet(isPresented: $appState.showCameraSheet) {
            CameraView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        
        // 5. History Sheet
        .sheet(isPresented: $appState.showHistorySheet) {
            HistoryView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        
        // 6. Daily Limit Reached Sheet
        .sheet(isPresented: $appState.showDailyLimitReached) {
            DailyLimitReachedView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .environmentObject(creditsService)
        }
        
        // 7. Auth Sheet (for unauthenticated users to sign in)
        .sheet(isPresented: $appState.showAuthSheet) {
            AuthView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        
        // MARK: - Notifications Lifecycle
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active || newPhase == .background {
                NotificationManager.shared.scheduleSmartNotifications()
            }
        }
        
        // MARK: - Deep Link Handling
        .onReceive(NotificationCenter.default.publisher(for: .handleDeepLink)) { _ in
            handlePendingDeepLink()
        }
    }
    
    // MARK: - Handle Deep Link from Notification
    private func handlePendingDeepLink() {
        guard let deepLink = UserDefaults.standard.string(forKey: "pending_deep_link") else { return }
        
        // Clear the pending deep link
        UserDefaults.standard.removeObject(forKey: "pending_deep_link")
        
        switch deepLink {
        case "home":
            appState.navigateTo(.home)
            
        case "history":
            appState.showHistorySheet = true
            
        case "creditsPaywall":
            appState.navigateTo(.creditsPaywall)
            
        default:
            if deepLink.hasPrefix("style:") {
                // Handle style deep link
                let styleId = String(deepLink.dropFirst(6))
                // TODO: Navigate to specific style
                appState.navigateTo(.home)
            } else if deepLink.hasPrefix("result:") {
                // Handle result deep link  
                let generationId = String(deepLink.dropFirst(7))
                // TODO: Navigate to specific result
                appState.showHistorySheet = true
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager())
}

// MARK: - Splash View
struct SplashView: View {
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0B0606")
            
            // Logo (static, no animation)
            Text("Eclat")
                .font(.custom("GTAlpinaTrial-CondensedThin", size: 64))
                .tracking(-2)
                .foregroundColor(.white)
        }
    }
}
