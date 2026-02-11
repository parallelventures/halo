//
//  SegmentedPaywallView.swift
//  Eclat
//
//  Server-driven, segment-based paywall system
//  Supports Entry, Packs, and Creator Mode with dynamic copy
//

import SwiftUI
import RevenueCat

// MARK: - Segmented Paywall View
struct SegmentedPaywallView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var creditsService: CreditsService
    @StateObject private var monetizationEngine = MonetizationEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    // Input: which offer to show
    let offerKey: OfferKey
    let surface: OfferSurface
    let copyVariant: CopyVariant?
    
    @State private var isPurchasing = false
    @State private var selectedPackId: String = "30looks"
    
    // Get user's selected styles from onboarding (for visual stack)
    private var selectedStyleImages: [String] {
        let onboardingData = OnboardingDataService.shared
        let category = onboardingData.localData.styleCategory
        let allStyles = category == "women" ? StylePreference.womenStyles : StylePreference.menStyles
        return Array(allStyles.compactMap { $0.image }.prefix(5))
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0B0606").ignoresSafeArea()
            
            switch offerKey {
            case .entry:
                entryPaywallContent
            case .packs:
                packsPaywallContent
            case .creatorMode:
                creatorModePaywallContent
            }
        }
        .onAppear {
            Task {
                await monetizationEngine.recordImpression(offerKey: offerKey, surface: surface)
            }
            Task {
                await subscriptionManager.fetchOfferings()
            }
        }
    }
    
    // MARK: - Entry Paywall ($2.99 one-time)
    private var entryPaywallContent: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
            
            // Title
            VStack(spacing: 8) {
                Text(copyVariant?.title ?? "Unlock your first looks")
                    .font(.eclat.displayLarge)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let subtitle = copyVariant?.subtitle {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            
            Spacer()
            
            // Style Stack
            styleStackVisual
            
            Spacer()
            
            // Bullets
            if let bullets = copyVariant?.bullets {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            Text(bullet)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
            
            // CTA
            Button {
                Task { await handleEntryPurchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text(copyVariant?.cta ?? "Unlock for $2.99")
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
            
            // Footnote
            if let footnote = copyVariant?.footnote {
                Text(footnote)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 12)
            }
            
            // Footer
            paywallFooter
                .padding(.top, 16)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - Packs Paywall
    private var packsPaywallContent: some View {
        VStack(spacing: 0) {
            topBar
            
            VStack(spacing: 8) {
                Text(copyVariant?.title ?? "Get more looks")
                    .font(.eclat.displayLarge)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let subtitle = copyVariant?.subtitle {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            
            Spacer()
            
            // Style Stack (smaller)
            styleStackVisual
                .scaleEffect(0.85)
            
            Spacer()
            
            // Pack Options
            VStack(spacing: 12) {
                PackOptionCard(
                    title: "10 Looks",
                    subtitle: "Quick decision",
                    price: subscriptionManager.allPackages.first(where: { $0.storeProduct.productIdentifier.contains("10looks") })?.localizedPriceString ?? "$9.99",
                    isSelected: selectedPackId == "10looks",
                    badge: nil
                ) {
                    selectedPackId = "10looks"
                }
                
                PackOptionCard(
                    title: "30 Looks",
                    subtitle: "Enough to truly decide",
                    price: subscriptionManager.allPackages.first(where: { $0.storeProduct.productIdentifier.contains("30looks") })?.localizedPriceString ?? "$22.99",
                    isSelected: selectedPackId == "30looks",
                    badge: "Most Popular"
                ) {
                    selectedPackId = "30looks"
                }
                
                PackOptionCard(
                    title: "100 Looks",
                    subtitle: "Explore freely",
                    price: subscriptionManager.allPackages.first(where: { $0.storeProduct.productIdentifier.contains("100looks") })?.localizedPriceString ?? "$44.99",
                    isSelected: selectedPackId == "100looks",
                    badge: nil
                ) {
                    selectedPackId = "100looks"
                }
            }
            .padding(.horizontal, 20)
            
            // CTA
            Button {
                Task { await handlePackPurchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text(copyVariant?.cta ?? "Get 30 Looks")
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
            .padding(.top, 20)
            
            // Footnote
            Text(copyVariant?.footnote ?? "Looks never expire.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 12)
            
            paywallFooter
                .padding(.top, 16)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - Creator Mode Paywall (Post-Result Upsell)
    private var creatorModePaywallContent: some View {
        VStack(spacing: 0) {
            topBar
            
            // Title - Post-AHA moment framing
            VStack(spacing: 8) {
                Text(copyVariant?.title ?? "You've unlocked your look.")
                    .font(.eclat.displayLarge)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(copyVariant?.subtitle ?? "Want to try more styles without limits?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            
            Spacer()
            
            // Style Stack
            styleStackVisual
            
            Spacer()
            
            // Bullets - Creator Mode benefits
            VStack(alignment: .leading, spacing: 14) {
                let bullets = copyVariant?.bullets ?? [
                    "Unlimited looks",
                    "Studio-grade quality", 
                    "No watermark",
                    "Priority generations"
                ]
                ForEach(bullets, id: \.self) { bullet in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                        Text(bullet)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
            
            // Primary CTA
            Button {
                Task { await handleCreatorModePurchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text(copyVariant?.cta ?? "Unlock Creator Mode")
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
            
            // Price subtitle
            Text("$12.99/week • Cancel anytime")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)
            
            // Secondary CTA - Fallback to looks packs
            Button {
                // Show packs instead
                appState.navigateTo(.creditsPaywall)
                dismiss()
            } label: {
                Text(copyVariant?.secondary ?? "Buy extra looks instead")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .underline()
            }
            .padding(.top, 16)
            
            paywallFooter
                .padding(.top, 20)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - Components
    private var topBar: some View {
        HStack {
            // Restore
            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Close
            Button {
                HapticManager.shared.buttonPress()
                Task {
                    await monetizationEngine.recordImpression(offerKey: offerKey, surface: surface, action: "dismissed")
                }
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
    
    private var styleStackVisual: some View {
        ZStack {
            let displayStyles = selectedStyleImages
            let count = min(5, displayStyles.count)
            let center = 2
            
            ForEach(0..<count, id: \.self) { index in
                let offset = index - center
                Image(displayStyles[index])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                    .rotationEffect(.degrees(Double(offset) * 6))
                    .offset(x: CGFloat(offset) * 25, y: CGFloat(abs(offset)) * 10)
                    .scaleEffect(1.0 - (CGFloat(abs(offset)) * 0.05))
                    .zIndex(Double(count - abs(offset)))
            }
        }
        .frame(height: 300)
    }
    
    private var paywallFooter: some View {
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
    }
    
    // MARK: - Purchase Handlers
    private func handleEntryPurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        guard let package = subscriptionManager.weeklyPackage ?? subscriptionManager.monthlyPackage else {
            subscriptionManager.errorMessage = "Unable to load purchase"
            return
        }
        
        do {
            try await subscriptionManager.purchase(package)
            await monetizationEngine.recordImpression(offerKey: .entry, surface: surface, action: "purchased")
            HapticManager.success()
            appState.forceClosePaywallAndNavigateToAuth()
        } catch SubscriptionManager.PurchaseError.cancelled {
            // 🚨 User cancelled - stay on paywall
            print("❌ Entry purchase cancelled by user")
        } catch {
            // Error handled by subscription manager
        }
    }
    
    private func handlePackPurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        guard let package = subscriptionManager.allPackages.first(where: { 
            $0.storeProduct.productIdentifier.contains(selectedPackId) 
        }) else {
            subscriptionManager.errorMessage = "Unable to load pack"
            return
        }
        
        do {
            try await subscriptionManager.purchase(package)
            await monetizationEngine.recordImpression(offerKey: .packs, surface: surface, action: "purchased")
            
            // Refund/Sync credits
            await creditsService.fetchBalance()
            
            // Post-purchase dopamine
            HapticManager.success()
            showPostPurchaseFeedback()
            appState.closePaywall()
        } catch SubscriptionManager.PurchaseError.cancelled {
            // 🚨 User cancelled - stay on paywall
            print("❌ Pack purchase cancelled by user")
        } catch {
            // Error handled
        }
    }
    
    private func handleCreatorModePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        guard let package = subscriptionManager.allPackages.first(where: { 
            $0.storeProduct.productIdentifier.contains("creator") || 
            $0.storeProduct.productIdentifier.contains("weekly")
        }) else {
            subscriptionManager.errorMessage = "Unable to load subscription"
            return
        }
        
        do {
            try await subscriptionManager.purchase(package)
            await monetizationEngine.recordImpression(offerKey: .creatorMode, surface: surface, action: "purchased")
            HapticManager.success()
            appState.closePaywall()
        } catch SubscriptionManager.PurchaseError.cancelled {
            // 🚨 User cancelled - stay on paywall
            print("❌ Creator mode purchase cancelled by user")
        } catch {
            // Error handled
        }
    }
    
    private func showPostPurchaseFeedback() {
        // The counter animation is handled in CreditsService
        // Just show a subtle toast
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Pack Option Card
struct PackOptionCard: View {
    let title: String
    let subtitle: String
    let price: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.buttonPress()
            action()
        }) {
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
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    SegmentedPaywallView(
        offerKey: .entry,
        surface: .sheet,
        copyVariant: CopyVariant(
            title: "Unlock your first looks",
            subtitle: "Preview your next hairstyle on you — instantly.",
            bullets: ["Realistic results", "Made to look like you", "Save & share"],
            cta: "Unlock for $2.99",
            footnote: "One-time purchase. No subscription."
        )
    )
    .environmentObject(AppState())
    .environmentObject(SubscriptionManager.shared)
    .environmentObject(CreditsService.shared)
}
