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
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    // Sync user with RevenueCat when authenticated
                    await syncUserWithRevenueCat()
                }
        }
    }
    
    // MARK: - Sync User with RevenueCat
    private func syncUserWithRevenueCat() async {
        // If user is logged in, sync with RevenueCat
        if let userId = UserDefaults.standard.string(forKey: "supabase_user_id"), !userId.isEmpty {
            await subscriptionManager.login(userID: userId)
        }
    }
}
