//
//  CreditsPaywallView.swift
//  Eclat
//
//  Top-up paywall for purchasing additional looks
//  Based on the premium design of PaywallView.swift
//

import SwiftUI
import RevenueCat
import UIKit

struct CreditsPaywallView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var creditsService: CreditsService
    
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showSuccessOverlay = false // Post-purchase magic
    
    // Design Helpers (copied from PaywallView for consistency)
    private var isSmallPhone: Bool { UIScreen.main.bounds.height < 700 }
    
    // Get user's selected styles from onboarding (reuse same logic for visual consistency)
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
        
        // Fallback
        if images.count < 5 {
            let remaining = allStyles.compactMap { $0.image }.filter { !images.contains($0) }
            images.append(contentsOf: remaining.prefix(5 - images.count))
        }
        
        return Array(images.prefix(5))
    }
    
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
                        // If user has credits, just go back. If not, go Home.
                        appState.navigateTo(.home) 
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
                
                // Hero content
                VStack(spacing: 8) {
                    Text("Keep exploring your looks")
                        .font(.eclat.displayLarge)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Don't stop your transformation now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Style Stack Visualization (Fanned Cards - reusable design)
                ZStack {
                    let displayStyles = selectedStyleImages
                    let count = min(5, displayStyles.count)
                    let center = 2
                    
                    ForEach(0..<count, id: \.self) { index in
                        let offset = index - center
                        Image(displayStyles[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: isSmallPhone ? 160 : 180, height: isSmallPhone ? 220 : 260)
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
                .padding(.bottom, 10)
                
                Spacer()
                
                // Bottom Pricing Section
                VStack(spacing: 16) {
                    
                    // Options List
                    VStack(spacing: 12) {
                        if let pkg30 = findPackage(id: "30looks") {
                            CreditsOptionCard(
                                title: "30 Looks",
                                price: pkg30.localizedPriceString,
                                subtitle: "Enough to really decide",
                                isSelected: selectedPackage?.identifier == pkg30.identifier,
                                badge: "MOST CHOSEN"
                            ) {
                                selectPackage(pkg30)
                            }
                        }
                        
                        if let pkg10 = findPackage(id: "10looks") {
                            CreditsOptionCard(
                                title: "10 Looks",
                                price: pkg10.localizedPriceString,
                                subtitle: "For a quick decision",
                                isSelected: selectedPackage?.identifier == pkg10.identifier,
                                badge: nil
                            ) {
                                selectPackage(pkg10)
                            }
                        }
                        
                        // 100 looks (Optional, maybe hidden if not fetched)
                        if let pkg100 = findPackage(id: "100looks") {
                            CreditsOptionCard(
                                title: "100 Looks",
                                price: pkg100.localizedPriceString,
                                subtitle: "Explore without limits",
                                isSelected: selectedPackage?.identifier == pkg100.identifier,
                                badge: "BEST VALUE"
                            ) {
                                selectPackage(pkg100)
                            }
                        }
                        
                        // Loading state fallback
                        if subscriptionManager.allPackages.isEmpty {
                            ProgressView()
                            .tint(.white)
                            .padding()
                        }
                    }
                    .padding(.horizontal, 20)

                    // Purchase Button
                    Button {
                        if let pkg = selectedPackage {
                            Task { await handlePurchase(pkg) }
                        }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView().tint(.black)
                            } else {
                                Text("Continue exploring")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white, in: Capsule())
                    }
                    .disabled(isPurchasing || selectedPackage == nil)
                    .padding(.horizontal, 20)
                    .opacity(selectedPackage == nil ? 0.5 : 1.0)
                    
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
                .padding(.bottom, 20)
            }
            .blur(radius: showSuccessOverlay ? 20 : 0) // Blur content behind overlay
            
            // MARK: - Post-Purchase Success Overlay
            if showSuccessOverlay {
                Color(hex: "0B0606")
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 20) {
                    Text("Your exploration continues.")
                        .font(.eclat.displayMedium)
                        .foregroundColor(.white)
                        .scaleEffect(1.0)
                        
                    Text("More freedom to explore.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .opacity(showSuccessOverlay ? 1 : 0)
                .animation(.easeIn(duration: 0.8).delay(0.2), value: showSuccessOverlay)
            }
        }
        .onAppear {
            Task {
                // Ensure we have fresh offerings
                await subscriptionManager.fetchOfferings()
                selectBestValuePackage()
            }
        }
        .alert("Error", isPresented: .constant(subscriptionManager.errorMessage != nil)) {
            Button("OK") { subscriptionManager.errorMessage = nil }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
    }
    
    // MARK: - Helpers
    private func findPackage(id: String) -> Package? {
        // Search by product identifier contains
        return subscriptionManager.allPackages.first { $0.storeProduct.productIdentifier.contains(id) }
    }
    
    private func selectPackage(_ package: Package) {
        HapticManager.shared.buttonPress()
        withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
            selectedPackage = package
        }
    }
    
    private func selectBestValuePackage() {
        // Auto-select 30 looks as it's "Most Popular"
        if let pkg = findPackage(id: "30looks") {
            selectedPackage = pkg
        } else if let pkg = findPackage(id: "10looks") {
            selectedPackage = pkg
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func handlePurchase(_ package: Package) async {
        isPurchasing = true
        
        do {
            try await subscriptionManager.purchase(package)
            
            TikTokService.shared.trackPurchase(
                productId: package.storeProduct.productIdentifier,
                productName: "Credits Topup",
                price: Double(truncating: NSDecimalNumber(decimal: package.storeProduct.price)),
                currency: package.storeProduct.currencyCode ?? "USD"
            )
            
            // 🚨 CRITICAL: Refresh credits from server immediately
            // The webhook finishes fast, so we should see the update
            await creditsService.fetchBalance()
            
            // Post-purchase emotional flow logic
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.3)) {
                    showSuccessOverlay = true
                }
            }
            
            // Deep Haptic Anchor
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay for sync
            await MainActor.run {
                 let impact = UIImpactFeedbackGenerator(style: .heavy) // Deep anchor
                 impact.impactOccurred()
            }
            
            // Wait for emotion to settle (1.5s total)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            // Return to previous flow
            await MainActor.run {
                if appState.capturedImage != nil {
                     appState.navigateTo(.processing)
                } else {
                     appState.navigateTo(.home)
                 }
            }
            
        } catch {
            if subscriptionManager.errorMessage == nil {
                subscriptionManager.errorMessage = "Purchase failed. Please try again."
            }
        }
        
        isPurchasing = false
    }
}

// MARK: - Credits Option Card (Custom styled for this view)
// Renamed to avoid usage conflict with global PlanCard
struct CreditsOptionCard: View {
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
                
                
                Spacer()
                
                // Price only (no checkmark/circle)
                Text(price)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(20) // Increased padding for premium feel
            .background(
                RoundedRectangle(cornerRadius: 24) // Increased radius
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

// MARK: - Premium Touch Button Style
// MARK: - Premium Touch Button Style
struct PremiumTouchButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0) // Ultra subtle scale
            .blur(radius: configuration.isPressed ? 0.5 : 0) // Light blur
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    // Deep/Subtle on press
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 1.0)
                } else {
                    // Release feedback
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
                }
            }
    }
}

#Preview {
    CreditsPaywallView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(CreditsService.shared)
}
