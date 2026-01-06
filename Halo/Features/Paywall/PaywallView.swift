//
//  PaywallView.swift
//  Halo
//
//  Fullscreen paywall with native mini sheet for pricing
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var showPricingSheet = false
    
    // Device detection
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var isLargePhone: Bool { UIScreen.main.bounds.height >= 800 }
    private var isSmallPhone: Bool { UIScreen.main.bounds.height < 700 }
    
    // Responsive dimensions - Supports iPhone mini to iPad
    private var imageSize: CGFloat { 
        if isIPad { return 280 }
        return isSmallPhone ? 100 : (isLargePhone ? 200 : 180) 
    }
    private var imageSizeLarge: CGFloat { 
        if isIPad { return 320 }
        return isSmallPhone ? 120 : (isLargePhone ? 220 : 200) 
    }
    private var imageHeight: CGFloat { 
        if isIPad { return 380 }
        return isSmallPhone ? 130 : (isLargePhone ? 270 : 240) 
    }
    private var imageHeightLarge: CGFloat { 
        if isIPad { return 420 }
        return isSmallPhone ? 150 : (isLargePhone ? 290 : 270) 
    }
    private var stackHeight: CGFloat { 
        if isIPad { return 450 }
        return isSmallPhone ? 160 : (isLargePhone ? 340 : 300) 
    }
    private var topSpacing: CGFloat { 
        if isIPad { return 80 }
        return isSmallPhone ? 10 : (isLargePhone ? 60 : 40) 
    }
    private var sheetHeight: CGFloat { 
        if isIPad { return 450 }
        return isSmallPhone ? 320 : 380 
    }
    private var imageOffset: CGFloat { 
        if isIPad { return 100 }
        return isSmallPhone ? 35 : 60 
    }
    
    var body: some View {
        ZStack {
            // Aurora background
            AnimatedDarkGradient()
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: isSmallPhone ? 16 : 30) {
                Spacer().frame(height: topSpacing)
                
                // Titles
                VStack(spacing: 12) {
                    Text("Unlock Halo Studio")
                        .font(.halo.displayLarge)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    
                    Text("See your perfect look today")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Stacked selfies preview
                ZStack {
                    // Selfie 1 (back)
                    Image("pw-selfie1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize, height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .rotationEffect(.degrees(-10))
                        .offset(x: -imageOffset, y: 15)
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                    
                    // Selfie 2 (middle)
                    Image("pw-selfie2")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize, height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .rotationEffect(.degrees(8))
                        .offset(x: imageOffset, y: 10)
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                    
                    // Selfie 3 (front)
                    Image("pw-selfie3")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSizeLarge, height: imageHeightLarge)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 18, y: 12)
                }
                .frame(height: stackHeight)
                
                Spacer()
            }
            
            // Top buttons (Close + Restore)
            VStack {
                HStack {
                    // Restore
                    Button {
                        Task {
                            try? await subscriptionManager.restorePurchases()
                            if subscriptionManager.isSubscribed {
                                appState.navigateTo(.result)
                            }
                        }
                    } label: {
                        Text("Restore")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.leading, 20)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    
                    Spacer()
                    
                    // Close
                    Button {
                        HapticManager.shared.buttonPress()
                        appState.navigateTo(.home)  // Go back to home (avoid showing unblurred result without payment)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 16)
                Spacer()
            }
        }
        .onAppear {
            Task {
                await subscriptionManager.fetchOfferings()
            }
            // Show sheet after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showPricingSheet = true
            }
        }
        .sheet(isPresented: $showPricingSheet) {
            PricingMiniSheet()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .presentationDetents([.height(sheetHeight)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled(true)
        }
    }
    
}

// MARK: - Pricing Mini Sheet
struct PricingMiniSheet: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var selectedPlan: PlanType = .annual
    @State private var isPurchasing = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Plan cards
            VStack(spacing: 10) {
                // Yearly Plan
                PlanCard(
                    title: "Yearly",
                    price: "$69.99/year",
                    subtitle: "Only $5.83/month • Save 60%",
                    isSelected: selectedPlan == .annual,
                    action: {
                        selectedPlan = .annual
                        HapticManager.shared.buttonPress()
                    }
                )
                
                // Monthly Plan
                PlanCard(
                    title: "Monthly",
                    price: "$14.99/month",
                    subtitle: "Billed monthly",
                    isSelected: selectedPlan == .monthly,
                    action: {
                        selectedPlan = .monthly
                        HapticManager.shared.buttonPress()
                    }
                )
            }
            

            
            // CTA Button
            Button {
                Task { await handlePurchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Unlock Halo Studio")
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
                        .foregroundColor(.black)
                }
                Text("4.8 • 2.3k ratings")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Footer
            VStack(spacing: 4) {
                Text("Auto-renewable • Cancel anytime")
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
        .alert("Error", isPresented: .constant(subscriptionManager.errorMessage != nil)) {
            Button("OK") { subscriptionManager.errorMessage = nil }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
    }
    
    private func handlePurchase() async {
        isPurchasing = true
        
        // Retry fetching offerings if not loaded
        if subscriptionManager.offerings == nil || subscriptionManager.allPackages.isEmpty {
            await subscriptionManager.fetchOfferings()
            // Wait a bit for offerings to load
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        let package = selectedPlan == .annual ? subscriptionManager.annualPackage : subscriptionManager.monthlyPackage
        
        guard let package = package else {
            subscriptionManager.errorMessage = "Unable to load subscription. Please try again."
            isPurchasing = false
            return
        }
        
        do {
            try await subscriptionManager.purchase(package)
            // Only navigate if purchase was successful AND subscription is active
            if subscriptionManager.isSubscribed {
                HapticManager.success()
                appState.navigateTo(.auth)  // Auth AFTER payment
            } else {
                // Purchase completed but subscription not active
                subscriptionManager.errorMessage = "Purchase completed but subscription could not be activated. Please contact support."
            }
        } catch {
            // Show error to user
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
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

#Preview {
    PaywallView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
}
