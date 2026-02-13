//
//  VariantAPaywallView.swift
//  Eclat
//
//  VARIANTE A — Hard Paywall Upfront (Projection-first)
//  "Je paie parce que je veux voir"
//
//  Flow: Onboarding → Paywall immédiat → Purchase → Auth → Home
//  Target: Users à intent élevé, max ARPU
//
//  Design: Premium, clean, sobre — inspired by CreditsPaywallView
//

import SwiftUI
import RevenueCat
import UIKit

struct VariantAPaywallView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPurchasing = false
    @State private var selectedPlan: PlanOption = .atelier
    
    enum PlanOption {
        case weekly   // Creator — $9.99/week, 20 looks/week
        case atelier  // Atelier — $29.99/month, unlimited + editorial + creative director
    }
    
    private var isSmallPhone: Bool { UIScreen.main.bounds.height < 700 }
    
    // Get user's selected styles from onboarding
    private var selectedStyleImages: [String] {
        let onboardingData = OnboardingDataService.shared
        let category = onboardingData.localData.styleCategory
        let allStyles = category == "women" ? StylePreference.womenStyles : StylePreference.menStyles
        return Array(allStyles.compactMap { $0.image }.prefix(5))
    }
    
    // Detect iPad for layout adjustments
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: "0B0606").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar
                    topBar
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Hero Title
                            VStack(spacing: 8) {
                                Text("See yourself with a new look")
                                    .font(.custom("GTAlpinaTrial-CondensedThin", size: isIPad ? 44 : 34))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Preview hairstyles with studio-grade realism")
                                    .font(.system(size: isIPad ? 17 : 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            
                            // Fanned Style Cards
                            styleStackVisual
                                .padding(.vertical, isIPad ? 16 : 10)
                            
                            // Pricing Section
                            pricingSection
                                .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                        }
                    }
                }
            }
        }
        .onAppear {
            TikTokService.shared.trackPaywallViewed(source: "variant_a")
            TikTokService.shared.trackExperimentPaywallViewed(
                variant: FunnelExperimentService.shared.variantLetter,
                source: "onboarding"
            )
            Task { await subscriptionManager.fetchOfferings() }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button {
                HapticManager.shared.buttonPress()
                TikTokService.shared.trackPaywallDismissed(selectedPlan: nil)
                appState.closePaywall()
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
    }
    
    // MARK: - Marquee State
    @State private var marqueeScrollIndex = 500 // Start in the middle
    private let marqueeTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    // MARK: - Marquee Visual
    private var styleStackVisual: some View {
        // Combine Styles and Colors for the marquee
        let styleImages = HairstyleData.women.compactMap { $0.imageName }
        let colorImages = HairColorData.allColors.map { $0.imageName }
        let allImages = styleImages + colorImages
        
        // Same sizes for iPhone and iPad (native support)
        let cardWidth: CGFloat = 220
        let cardHeight: CGFloat = 310
        let cardCornerRadius: CGFloat = 24
        
        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: isIPad ? 10 : 12) {
                        // Create a virtual infinite list
                        ForEach(0..<1000) { index in
                            let imageName = allImages.isEmpty ? "" : allImages[index % allImages.count]
                            let isActive = index == marqueeScrollIndex
                            
                            VStack(spacing: 0) {
                                Image(imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: cardWidth, height: cardHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                                    .shadow(color: .black.opacity(isActive ? 0.5 : 0.2), radius: isActive ? 12 : 5)
                            }
                            .id(index)
                            .scaleEffect(isActive ? 1.05 : 0.95)
                            .opacity(isActive ? 1.0 : 0.8)
                            .blur(radius: isActive ? 0 : 0.5)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: marqueeScrollIndex)
                        }
                    }
                    .padding(.horizontal, (geo.size.width - cardWidth) / 2)
                }
                .scrollDisabled(true)
                .onReceive(marqueeTimer) { _ in
                    let nextIndex = marqueeScrollIndex + 1
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                        marqueeScrollIndex = nextIndex
                        proxy.scrollTo(nextIndex, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(marqueeScrollIndex, anchor: .center)
                }
            }
        }
        .frame(height: isIPad ? 280 : 350)
    }
    
    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: 16) {
            // Plan Options
            VStack(spacing: 12) {
                // Atelier Plan — highlighted as best value
                SubscriptionOptionCard(
                    title: "Atelier",
                    price: {
                        if let p = subscriptionManager.findPackage(byProductId: "atelier")?.localizedPriceString {
                            return "\(p)/mo"
                        }
                        return "$29.99/mo"
                    }(),
                    subtitle: "Unlimited Looks · Studio-Grade Quality · Editorial Mode ",
                    isSelected: selectedPlan == .atelier,
                    badge: "BEST VALUE"
                ) {
                    withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
                        selectedPlan = .atelier
                    }
                }
                
                // Creator Plan — weekly
                SubscriptionOptionCard(
                    title: "Creator",
                    price: {
                        if let p = subscriptionManager.findPackage(byProductId: "weekly")?.localizedPriceString {
                            return "\(p)/wk"
                        }
                        return "$9.99/wk"
                    }(),
                    subtitle: "20 looks per week",
                    isSelected: selectedPlan == .weekly,
                    badge: nil
                ) {
                    withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
                        selectedPlan = .weekly
                    }
                }
            }
            
            // CTA Button
            GlassCapsuleButton(
                title: selectedPlan == .atelier ? "Unlock Atelier" : "Go Creator",
                systemImage: selectedPlan == .atelier ? "sparkles" : "infinity",
                shimmer: true,
                isLoading: isPurchasing
            ) {
                Task { await handlePurchase() }
            }
            .disabled(isPurchasing)
            
            // Reassurance text
            Text("Auto-renewable · No commitment · Cancel anytime")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 8)
            
            // Legal links - required by App Store Guidelines 3.1.2
            HStack(spacing: 8) {
                Button("Terms of Use") { openURL("https://parallelventures.eu/terms-of-use/") }
                Text("·").foregroundColor(.white.opacity(0.3))
                Button("Privacy Policy") { openURL("https://parallelventures.eu/privacy-policy/") }
            }
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.4))
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 500) // iPad constraint
    }
    
    // MARK: - Open URL Helper
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Purchase Handler
    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        let targetProductId: String
        let planType: String
        let price: Double
        
        switch selectedPlan {
        case .atelier:
            targetProductId = "atelier"
            planType = "atelier"
            price = 29.99
        case .weekly:
            targetProductId = "weekly"
            planType = "weekly"
            price = 9.99
        }
        
        // 1. Find Package in ANY Offering
        guard let package = subscriptionManager.findPackage(byProductId: targetProductId) else {
            print("❌ Critical: Package \(targetProductId) not found in any Offering.")
            subscriptionManager.errorMessage = "Configuration Error: Product not found in Offerings."
            return
        }
        
        print("🛒 Initiating purchase for Package: \(package.identifier) (Product: \(targetProductId))")
        
        TikTokService.shared.trackCheckoutInitiated(planType: planType, price: price)
        TikTokService.shared.trackExperimentCheckout(
            variant: FunnelExperimentService.shared.variantLetter,
            planType: planType,
            price: price
        )
        
        do {
            // 2. Purchase the PACKAGE (Preserves Metadata & Webhooks)
            try await subscriptionManager.purchase(package)
            
            HapticManager.success()
            appState.forceClosePaywallAndNavigateToAuth()
            
        } catch SubscriptionManager.PurchaseError.cancelled {
            TikTokService.shared.trackPaywallDismissed(selectedPlan: planType)
        } catch {
            print("❌ Purchase failed: \(error)")
        }
    }
}

// MARK: - Subscription Option Card (Premium Style)
struct SubscriptionOptionCard: View {
    let title: String
    let price: String
    let subtitle: String
    let isSelected: Bool
    var badge: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white, in: Capsule())
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text(price)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 0.5)
                    )
            )
        }
        .buttonStyle(PremiumTouchButtonStyle())
    }
}

#Preview {
    VariantAPaywallView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
}
