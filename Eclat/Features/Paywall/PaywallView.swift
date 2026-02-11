//
//  PaywallView.swift
//  Eclat
//
//  Fullscreen paywall with native mini sheet for pricing
//

import SwiftUI
import UIKit
import RevenueCat

struct PaywallView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPurchasing = false
    
    // Get user's selected styles from onboarding (5 for fanned stack)
    private var selectedStyleImages: [String] {
        let onboardingData = OnboardingDataService.shared
        let category = onboardingData.localData.styleCategory
        let likedStyleNames = onboardingData.getLikedStyles()
        let allStyles = category == "women" ? StylePreference.womenStyles : StylePreference.menStyles
        
        var images: [String] = []
        for styleName in likedStyleNames {
            if let style = allStyles.first(where: { $0.name == styleName }), let imageName = style.image {
                images.append(imageName)
            }
        }
        
        // Fallback: if not enough liked styles, add from all styles
        if images.count < 5 {
            let remaining = allStyles.compactMap { $0.image }.filter { !images.contains($0) }
            images.append(contentsOf: remaining.prefix(5 - images.count))
        }
        
        return Array(images.prefix(5))
    }
    
    // Responsive dimensions
    private var isSmallPhone: Bool { UIScreen.main.bounds.height < 700 }
    private var isLargePhone: Bool { UIScreen.main.bounds.height >= 800 }
    private var imageSize: CGFloat { isSmallPhone ? 100 : (isLargePhone ? 180 : 160) }
    private var imageSizeLarge: CGFloat { isSmallPhone ? 120 : (isLargePhone ? 200 : 180) }
    private var imageHeight: CGFloat { isSmallPhone ? 130 : (isLargePhone ? 240 : 220) }
    private var imageHeightLarge: CGFloat { isSmallPhone ? 150 : (isLargePhone ? 260 : 240) }
    private var stackHeight: CGFloat { isSmallPhone ? 160 : (isLargePhone ? 300 : 280) }
    private var imageOffset: CGFloat { isSmallPhone ? 35 : 55 }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top buttons
                HStack {
                    // Restore
                    Button {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.hasLooks {
                                appState.navigateTo(.processing)
                            }
                        }
                    } label: {
                        Text("Restore")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Close - Glass effect (same as HomeView icons)
                    Button {
                        HapticManager.shared.buttonPress()
                        appState.closePaywall() // Correctly dismisses the sheet
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                    }
                    .glassCircleButton()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Hero content - HIGH position
                VStack(spacing: 8) {
                    Text("Your look is ready")
                        .font(.eclat.displayLarge)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Generated just now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                
                Spacer()
                
                // Style Stack Visualization (5 images like Styles Ready)
                ZStack {
                    let displayStyles = selectedStyleImages
                    let count = min(5, displayStyles.count)
                    let center = 2 // Center index for 5 cards
                    
                    ForEach(0..<count, id: \.self) { index in
                        let offset = index - center
                        Image(displayStyles[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                            .rotationEffect(.degrees(Double(offset) * 6))
                            .offset(x: CGFloat(offset) * 30, y: CGFloat(abs(offset)) * 10)
                            .scaleEffect(1.0 - (CGFloat(abs(offset)) * 0.05))
                            .zIndex(Double(count - abs(offset)))
                    }
                }
                .frame(height: 380)
                
                Spacer()
                
                // Bottom pricing section
                VStack(spacing: 12) {
                    
                    // CTA Button with price
                    Button {
                        print("🔥🔥🔥 MAIN PAYWALL BUTTON TAPPED")
                        Task { 
                            print("🔥🔥🔥 MAIN PAYWALL TASK CREATED")
                            await handlePurchase() 
                        }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Unlock My Look — $2.99")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white, in: Capsule())
                    }
                    .disabled(isPurchasing)
                    .padding(.horizontal, 20)
                    .buttonStyle(ScaleOnPressButtonStyle())
                    
                    // One-time unlock label
                    Text("One-time unlock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    // Footer
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                            }
                            Text("4.8 • 2.3k ratings")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        HStack(spacing: 8) {
                            Button("Terms") { openURL("https://parallelventures.eu/terms-of-use/") }
                            Text("•").foregroundColor(.white.opacity(0.3))
                            Button("Privacy") { openURL("https://parallelventures.eu/privacy-policy/") }
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.bottom, 16)
                }
                .padding(.top, 20)
            }
        }
        .onAppear {
            print("🟢🟢🟢 PaywallView APPEARED!")
            print("🟢 isPurchasing: \(isPurchasing)")
            Task {
                await subscriptionManager.fetchOfferings()
                print("🟢 Offerings fetched: \(subscriptionManager.allPackages.count) packages")
            }
            TikTokService.shared.trackPaywallViewed(source: "onboarding")
        }
        .alert("Error", isPresented: Binding(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                subscriptionManager.errorMessage = nil
            }
        } message: {
            Text(subscriptionManager.errorMessage ?? "Unknown error")
        }
    }
    
    // MARK: - Handle Purchase
    private func handlePurchase() async {
        isPurchasing = true
        
        if subscriptionManager.offerings == nil || subscriptionManager.allPackages.isEmpty {
            await subscriptionManager.fetchOfferings()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        let package = subscriptionManager.weeklyPackage ?? subscriptionManager.monthlyPackage
        
        guard let package = package else {
            subscriptionManager.errorMessage = "Unable to load purchase. Please try again."
            isPurchasing = false
            return
        }
        
        TikTokService.shared.trackCheckoutInitiated(planType: "entry", price: 2.99)
        
        do {
            try await subscriptionManager.purchase(package)
            
            print("🔥 Purchase SUCCESS - closing paywall now")
            
            // Track purchase
            TikTokService.shared.trackPurchase(
                productId: package.storeProduct.productIdentifier,
                productName: "Eclat Entry",
                price: 2.99,
                currency: "USD"
            )
            HapticManager.success()
            
            // FORCE close paywall and navigate
            // Rely completely on AppState to manage the sheet state
            appState.forceClosePaywallAndNavigateToAuth()
            print("🔥 Done - trigger force close sequence")
        } catch SubscriptionManager.PurchaseError.cancelled {
            // 🚨 User cancelled - just reset state, don't navigate or show error
            print("🔥 Purchase cancelled by user - staying on paywall")
            TikTokService.shared.trackPaywallDismissed(selectedPlan: "entry")
        } catch {
            TikTokService.shared.trackPaywallDismissed(selectedPlan: "entry")
            if subscriptionManager.errorMessage == nil {
                subscriptionManager.errorMessage = "Purchase failed. Please try again."
            }
        }
        
        isPurchasing = false
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Pricing Mini Sheet (Single $2.99 Entry Point)
struct PricingMiniSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Binding var showSheet: Bool
    
    @State private var isPurchasing = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Single price point - Clean and simple
            VStack(spacing: 8) {
                Text("$2.99")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("one-time purchase")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            // CTA Button
            Button {
                print("🔥🔥🔥 BUTTON TAPPED - BEFORE TASK")
                Task { 
                    print("🔥🔥🔥 INSIDE TASK - BEFORE AWAIT")
                    await handlePurchase() 
                }
                print("🔥🔥🔥 BUTTON TAPPED - AFTER TASK CREATED")
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Unlock My Looks")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white, in: Capsule())
            }
            .disabled(isPurchasing)
            
            // Social proof
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }
                Text("4.8 • 2.3k ratings")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Footer
            VStack(spacing: 4) {
                Text("Instant access • No subscription")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Button("Terms") { openURL("https://parallelventures.eu/terms-of-use/") }
                    Text("•").foregroundColor(.secondary)
                    Button("Privacy") { openURL("https://parallelventures.eu/privacy-policy/") }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 0)
        .alert("Error", isPresented: Binding(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                subscriptionManager.errorMessage = nil
            }
        } message: {
            Text(subscriptionManager.errorMessage ?? "Unknown error")
        }
    }
    
    private func handlePurchase() async {
        print("🔥 DEBUG: handlePurchase() CALLED")
        isPurchasing = true
        print("🔥 DEBUG: isPurchasing set to TRUE")
        
        // Retry fetching offerings if not loaded
        print("🔥 DEBUG: Checking offerings...")
        print("🔥 DEBUG: offerings = \(subscriptionManager.offerings != nil)")
        print("🔥 DEBUG: allPackages count = \(subscriptionManager.allPackages.count)")
        
        if subscriptionManager.offerings == nil || subscriptionManager.allPackages.isEmpty {
            print("🔥 DEBUG: Fetching offerings...")
            await subscriptionManager.fetchOfferings()
            try? await Task.sleep(nanoseconds: 500_000_000)
            print("🔥 DEBUG: After fetch - packages count = \(subscriptionManager.allPackages.count)")
        }
        
        // Get the $2.99 entry point package
        print("🔥 DEBUG: Looking for package...")
        print("🔥 DEBUG: weeklyPackage = \(subscriptionManager.weeklyPackage != nil)")
        print("🔥 DEBUG: monthlyPackage = \(subscriptionManager.monthlyPackage != nil)")
        
        let package = subscriptionManager.weeklyPackage ?? subscriptionManager.monthlyPackage
        let planName = "entry_point"
        let price = 2.99
        
        guard let package = package else {
            print("🔥 DEBUG: ❌ NO PACKAGE FOUND - Setting error")
            subscriptionManager.errorMessage = "Unable to load purchase. Please try again."
            isPurchasing = false
            print("🔥 DEBUG: Error message set: \(subscriptionManager.errorMessage ?? "nil")")
            return
        }
        
        print("🔥 DEBUG: ✅ Package found: \(package.storeProduct.productIdentifier)")
        
        // Track checkout initiated
        TikTokService.shared.trackCheckoutInitiated(planType: planName, price: price)
        
        do {
            print("🔥 DEBUG: Calling purchase()...")
            try await subscriptionManager.purchase(package)
            print("🔥 DEBUG: Purchase completed!")
            
            // Only navigate if purchase was successful AND subscription is active
            if subscriptionManager.isSubscribed {
                print("🔥 DEBUG: ✅ User is now subscribed!")
                // Track successful purchase with TikTok
                TikTokService.shared.trackPurchase(
                    productId: package.storeProduct.productIdentifier,
                    productName: "Eclat Entry",
                    price: price,
                    currency: "USD"
                )
                TikTokService.shared.trackSubscribe(planType: planName, price: price)
                
                HapticManager.success()
                
                // FORCE dismiss the sheet
                showSheet = false
                dismiss()
                
                // Navigate after a slight delay to ensure sheet is gone
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    appState.navigateTo(.auth)  // Auth AFTER payment
                }
            } else {
                print("🔥 DEBUG: ⚠️ Purchase completed but not activated")
                subscriptionManager.errorMessage = "Purchase completed but could not be activated. Please contact support."
            }
        } catch SubscriptionManager.PurchaseError.cancelled {
            // 🚨 User cancelled - just reset state, don't show error
            print("🔥 DEBUG: Purchase cancelled by user - staying on paywall")
            TikTokService.shared.trackPaywallDismissed(selectedPlan: planName)
        } catch {
            print("🔥 DEBUG: ❌ Purchase FAILED: \(error.localizedDescription)")
            // Track paywall dismissed without purchase
            TikTokService.shared.trackPaywallDismissed(selectedPlan: planName)
            // Show error to user
            if subscriptionManager.errorMessage == nil {
                subscriptionManager.errorMessage = "Purchase failed. Please try again."
            }
            print("🔥 DEBUG: Error message: \(subscriptionManager.errorMessage ?? "nil")")
        }
        
        print("🔥 DEBUG: Setting isPurchasing to FALSE")
        isPurchasing = false
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Plan Type
enum PlanType {
    case monthly
    case annual
}

// MARK: - Plan Card
struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let isSelected: Bool
    var badge: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green, in: Capsule())
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(price)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paywall Bullet
struct PaywallBullet: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Bullet Point (for mini sheet)
struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text("•")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Premium Button Style (Scale + Blur + Haptic)
struct ScaleOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .blur(radius: configuration.isPressed ? 2 : 0)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    let impact = UIImpactFeedbackGenerator(style: .soft)
                    impact.impactOccurred(intensity: 1.0)
                }
            }
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
}
