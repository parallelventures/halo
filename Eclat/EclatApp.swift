//
//  EclatApp.swift
//  Eclat: Preview your look
//
//  Created with ❤️ for amazing hair transformations
//

import SwiftUI
import GoogleSignIn
import RevenueCat


@main
struct EclatApp: App {
    
    // MARK: - App Delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - State Objects
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var cameraService = CameraService()
    @StateObject private var creditsService = CreditsService.shared
    
    // MARK: - Init
    init() {
        // Configure RevenueCat
        SubscriptionManager.shared.configure()
        
        // Configure TikTok SDK
        TikTokService.shared.configure()
    }
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .environmentObject(cameraService)
                .environmentObject(creditsService)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle eclat:// deep links
                    if url.scheme == "eclat" {
                        Task { @MainActor in
                            NotificationManager.shared.handleDeepLink(url)
                        }
                    } else {
                        // Handle Google Sign-In callback
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
                .task {
                    // Track app launch
                    TikTokService.shared.trackAppLaunch()
                    
                    // Refresh session if user was previously authenticated
                    if AuthService.shared.isAuthenticated {
                        _ = await AuthService.shared.refreshSession()
                    } else if UserDefaults.standard.string(forKey: "supabase_refresh_token") != nil {
                        // Has refresh token but not marked as authenticated, try to restore
                        _ = await AuthService.shared.refreshSession()
                    }
                    
                    // Sign in anonymously if still not authenticated
                    if !AuthService.shared.isAuthenticated {
                        await AuthService.shared.signInAnonymously()
                    }
                    
                    // Sync user with RevenueCat when authenticated
                    await syncUserWithRevenueCat()
                    
                    // Sync credits post-auth
                    await creditsService.syncAfterAuth()
                }
        }
    }
    
    // MARK: - Sync User with RevenueCat
    private func syncUserWithRevenueCat() async {
        // If user is logged in, sync with RevenueCat
        if let userId = AuthService.shared.userId {
            await subscriptionManager.login(userID: userId)
        }
    }
}
