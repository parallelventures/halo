//
//  HaloApp.swift
//  Halo - AI Hairstyle Try-On
//
//  Created with ❤️ for amazing hair transformations
//

import SwiftUI
import GoogleSignIn
import RevenueCat

@main
struct HaloApp: App {
    
    // MARK: - State Objects
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var cameraService = CameraService()
    
    // MARK: - Init
    init() {
        // Configure RevenueCat
        SubscriptionManager.shared.configure()
    }
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .environmentObject(cameraService)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
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
