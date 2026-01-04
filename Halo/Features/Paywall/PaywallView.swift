//
//  PaywallView.swift
//  Halo
//
//  Premium paywall with RevenueCat integration
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var selectedPlanIndex: Int = 1 // 0 = monthly, 1 = annual
    @State private var isVisible = false
    
    private var selectedPackage: Package? {
        selectedPlanIndex == 1 ? subscriptionManager.annualPackage : subscriptionManager.monthlyPackage
    }
    
    var body: some View {
        ZStack {
            // Aurora background
            AnimatedDarkGradient()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // Close
                    HStack {
                        Spacer()
                        HaloIconButton(icon: "xmark") {
                            appState.navigateTo(.result)
                        }
                    }
                    .padding(.top, Spacing.md)
                    
                    // Header
                    VStack(spacing: Spacing.md) {
                        Circle()
                            .fill(Color.theme.glassFill)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .strokeBorder(LinearGradient.haloPrimary, lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(LinearGradient.haloPrimary)
                            )
                        
                        Text("Unlock Halo Pro")
                            .font(.halo.displayMedium)
                            .foregroundColor(.theme.textPrimary)
                        
                        Text("See your amazing transformation\nand explore unlimited styles")
                            .font(.halo.bodyMedium)
                            .foregroundColor(.theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Preview teaser
                    if let image = appState.generatedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                            .blur(radius: 20)
                            .overlay(
                                VStack(spacing: Spacing.sm) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 28))
                                        .foregroundStyle(LinearGradient.haloPrimary)
                                    
                                    Text("Your result is ready!")
                                        .font(.halo.labelLarge)
                                        .foregroundColor(.white)
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.lg)
                                    .strokeBorder(Color.theme.glassBorder, lineWidth: 1)
                            )
                    }
                    
                    // Pricing from RevenueCat
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    } else {
                        VStack(spacing: Spacing.md) {
                            // Annual Plan
                            if let annual = subscriptionManager.annualPackage {
                                RevenueCatPricingCard(
                                    package: annual,
                                    isPopular: true,
                                    isSelected: selectedPlanIndex == 1
                                ) {
                                    withAnimation(.haloQuick) {
                                        selectedPlanIndex = 1
                                    }
                                }
                            }
                            
                            // Monthly Plan
                            if let monthly = subscriptionManager.monthlyPackage {
                                RevenueCatPricingCard(
                                    package: monthly,
                                    isPopular: false,
                                    isSelected: selectedPlanIndex == 0
                                ) {
                                    withAnimation(.haloQuick) {
                                        selectedPlanIndex = 0
                                    }
                                }
                            }
                        }
                    }
                    
                    // CTA
                    VStack(spacing: Spacing.md) {
                        HaloCTAButton(
                            "Start \(selectedPlanIndex == 1 ? "Annual" : "Monthly") Plan",
                            isLoading: subscriptionManager.isLoading
                        ) {
                            Task { await purchase() }
                        }
                        .disabled(selectedPackage == nil)
                        
                        if selectedPlanIndex == 1, let savings = subscriptionManager.annualPackage?.savingsPercentage {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "tag.fill")
                                    .font(.caption)
                                Text("Save \(savings)%")
                                    .font(.halo.labelSmall)
                            }
                            .foregroundColor(.theme.success)
                        }
                    }
                    
                    // Footer
                    VStack(spacing: Spacing.md) {
                        Button("Restore Purchases") {
                            Task {
                                do {
                                    try await subscriptionManager.restorePurchases()
                                    if subscriptionManager.isSubscribed {
                                        appState.navigateTo(.result)
                                    }
                                } catch {
                                    // Error handled in manager
                                }
                            }
                        }
                        .font(.halo.labelMedium)
                        .foregroundColor(.theme.textSecondary)
                        
                        HStack(spacing: Spacing.lg) {
                            Button("Terms") {}
                                .font(.halo.caption)
                                .foregroundColor(.theme.textTertiary)
                            
                            Button("Privacy") {}
                                .font(.halo.caption)
                                .foregroundColor(.theme.textTertiary)
                        }
                        
                        Text("Subscription automatically renews unless cancelled at least 24 hours before the current period ends.")
                            .font(.halo.caption)
                            .foregroundColor(.theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .padding(.horizontal, Spacing.lg)
            }
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.haloSmooth) {
                isVisible = true
            }
            // Refresh offerings
            Task {
                await subscriptionManager.fetchOfferings()
            }
        }
        .alert("Error", isPresented: .constant(subscriptionManager.errorMessage != nil)) {
            Button("OK") { subscriptionManager.errorMessage = nil }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
    }
    
    private func purchase() async {
        guard let package = selectedPackage else { return }
        
        do {
            try await subscriptionManager.purchase(package)
            if subscriptionManager.isSubscribed {
                appState.navigateTo(.result)
            }
        } catch {
            // Error handled in manager
        }
    }
}

// MARK: - RevenueCat Pricing Card
struct RevenueCatPricingCard: View {
    let package: Package
    let isPopular: Bool
    let isSelected: Bool
    let action: () -> Void
    
    private var title: String {
        switch package.packageType {
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        default:
            return package.storeProduct.localizedTitle
        }
    }
    
    private var pricePerPeriod: String {
        switch package.packageType {
        case .annual:
            return "\(package.localizedPricePerMonth)/mo"
        case .monthly:
            return "\(package.storeProduct.localizedPriceString)/mo"
        default:
            return package.storeProduct.localizedPriceString
        }
    }
    
    private var billingInfo: String {
        switch package.packageType {
        case .annual:
            return "Billed \(package.storeProduct.localizedPriceString) annually"
        case .monthly:
            return "Billed monthly"
        default:
            return ""
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.halo.labelLarge)
                            .foregroundColor(.theme.textPrimary)
                        
                        if isPopular {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient.haloPrimary,
                                    in: Capsule()
                                )
                        }
                    }
                    
                    Text(billingInfo)
                        .font(.halo.caption)
                        .foregroundColor(.theme.textSecondary)
                }
                
                Spacer()
                
                Text(pricePerPeriod)
                    .font(.halo.labelLarge)
                    .foregroundColor(.theme.textPrimary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(isSelected ? Color.theme.accentPrimary.opacity(0.15) : Color.theme.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .strokeBorder(
                        isSelected ? Color.theme.accentPrimary : Color.theme.glassBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}
