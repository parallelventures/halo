//
//  SubscriptionManager.swift
//  Eclat
//
//  RevenueCat integration for subscription management
//  Two-tier system: Creator (weekly) and Atelier (monthly)
//  RevenueCat is the SINGLE source of truth for entitlements
//

import Foundation
import UIKit
import RevenueCat

// MARK: - RevenueCat Configuration
struct RevenueCatConfig {
    static let apiKey = "appl_aItvxVcPPogBXOONwvaVHYvBBcN"
}

// MARK: - Subscription Tier
enum SubscriptionTier: String, CaseIterable {
    case free = "free"
    case creator = "creator"     // Weekly — 20 looks/week
    case atelier = "atelier"     // Monthly $29.99 — Unlimited + Editorial + Creative Director
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .creator: return "Creator Mode"
        case .atelier: return "Atelier"
        }
    }
    
    var weeklyLooksLimit: Int? {
        switch self {
        case .free: return 0
        case .creator: return 20
        case .atelier: return nil  // Unlimited
        }
    }
    
    var hasEditorialMode: Bool {
        self == .atelier
    }
    
    var hasCreativeDirector: Bool {
        self == .atelier
    }
}

// MARK: - Subscription Manager
@MainActor
final class SubscriptionManager: NSObject, ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var isAtelierSubscriber: Bool = false
    @Published private(set) var currentTier: SubscriptionTier = .free
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Weekly Looks Tracking (Creator tier: 20/week)
    private static let weeklyLooksUsedKey = "weekly_looks_used"
    private static let weeklyLooksResetKey = "weekly_looks_reset_date"
    
    @Published private(set) var weeklyLooksUsed: Int = 0
    
    // MARK: - Computed Properties
    
    /// Whether user has looks available to generate
    var hasLooks: Bool {
        switch currentTier {
        case .atelier: return true           // Unlimited
        case .creator: return weeklyLooksRemaining > 0  // 20/week
        case .free:    return false           // Must upgrade
        }
    }
    
    /// Remaining weekly looks for Creator tier
    var weeklyLooksRemaining: Int {
        guard let limit = currentTier.weeklyLooksLimit else { return Int.max }
        return max(0, limit - weeklyLooksUsed)
    }
    
    /// Display text for the HomeView header
    var looksDisplayText: String {
        switch currentTier {
        case .atelier: return "Unlimited Looks"
        case .creator: return "\(weeklyLooksRemaining) Looks"
        case .free:    return "0 Looks"
        }
    }
    
    /// Whether user can generate (alias for hasLooks)
    var canGenerate: Bool { hasLooks }
    
    /// Whether user is a PAID subscriber (same as isSubscribed — no trials)
    var isPaidSubscriber: Bool { isSubscribed }
    
    /// Whether user has access to Editorial Mode (Atelier only)
    var hasEditorialAccess: Bool { currentTier.hasEditorialMode }
    
    /// Whether user has access to Creative Director AI chat (Atelier only)
    var hasCreativeDirectorAccess: Bool { currentTier.hasCreativeDirector }
    
    // MARK: - Packages
    
    var weeklyPackage: Package? {
        offerings?.current?.weekly ?? offerings?.current?.package(identifier: "weekly")
    }
    
    var monthlyPackage: Package? {
        offerings?.current?.monthly ?? offerings?.current?.package(identifier: "monthly")
    }
    
    var allPackages: [Package] {
        offerings?.current?.availablePackages ?? []
    }
    
    /// Finds a package by its product identifier across ALL offerings.
    func findPackage(byProductId id: String) -> Package? {
        guard let offerings = offerings else { return nil }
        
        // 1. Search in Current Offering first
        if let pkg = offerings.current?.availablePackages.first(where: { $0.storeProduct.productIdentifier.hasSuffix(id) }) {
            return pkg
        }
        
        // 2. Search in ALL other offerings
        for offering in offerings.all.values {
            if let pkg = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier.hasSuffix(id) }) {
                return pkg
            }
        }
        
        return nil
    }
    
    // MARK: - Init
    override init() {
        super.init()
        loadWeeklyLooksState()
    }
    
    // MARK: - Weekly Looks Tracking
    
    /// Record a look used (called after successful generation)
    func recordLookUsed() {
        guard currentTier == .creator else { return } // Only track for Creator
        checkAndResetWeeklyLooks()
        weeklyLooksUsed += 1
        UserDefaults.standard.set(weeklyLooksUsed, forKey: Self.weeklyLooksUsedKey)
        print("👁️ Look used: \(weeklyLooksUsed)/20 this week")
    }
    
    private func loadWeeklyLooksState() {
        weeklyLooksUsed = UserDefaults.standard.integer(forKey: Self.weeklyLooksUsedKey)
        checkAndResetWeeklyLooks()
    }
    
    /// Reset weekly looks counter if 7 days have passed
    private func checkAndResetWeeklyLooks() {
        if let resetDate = UserDefaults.standard.object(forKey: Self.weeklyLooksResetKey) as? Date {
            if Date() >= resetDate {
                weeklyLooksUsed = 0
                UserDefaults.standard.set(0, forKey: Self.weeklyLooksUsedKey)
                let nextReset = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
                UserDefaults.standard.set(nextReset, forKey: Self.weeklyLooksResetKey)
                print("🔄 Weekly looks reset! Next reset: \(nextReset)")
            }
        } else {
            // First time — set reset date to 7 days from now
            let nextReset = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
            UserDefaults.standard.set(nextReset, forKey: Self.weeklyLooksResetKey)
        }
    }
    
    // MARK: - Configure RevenueCat
    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        Purchases.shared.delegate = self
        
        Task {
            await fetchOfferings()
            await refreshCustomerInfo()
            
            // Auto-restore at app launch to recover orphaned subscriptions
            if !isSubscribed {
                print("🔄 No subscription found at launch, attempting restore...")
                await restorePurchasesSilently()
            }
        }
    }
    
    // MARK: - Refresh Customer Info
    func refreshCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            updateSubscriptionStatus(customerInfo)
        } catch {
            print("❌ Failed to get customer info: \(error)")
        }
    }
    
    // MARK: - Update Subscription Status
    private func updateSubscriptionStatus(_ customerInfo: CustomerInfo) {
        // Primary: Check RevenueCat entitlements
        let hasCreator = customerInfo.entitlements["creator"]?.isActive == true
        let hasAtelier = customerInfo.entitlements["atelier"]?.isActive == true
        // Legacy: "Studio" entitlement from older RC configuration
        let hasStudio = customerInfo.entitlements["Studio"]?.isActive == true
        
        // Fallback: Also check activeSubscriptions directly
        // This catches cases where the product → entitlement mapping is delayed or misconfigured
        let hasAnyActiveSubscription = !customerInfo.activeSubscriptions.isEmpty
        
        // Check if any active subscription product ID contains "atelier"
        let hasAtelierProduct = customerInfo.activeSubscriptions.contains { $0.lowercased().contains("atelier") }
        
        if hasAnyActiveSubscription && !hasCreator && !hasAtelier && !hasStudio {
            print("⚠️ ENTITLEMENT MISMATCH: User has active subscriptions \(customerInfo.activeSubscriptions) but NO entitlements! Granting access anyway.")
        }
        
        // Atelier includes creator features
        isSubscribed = hasCreator || hasAtelier || hasStudio || hasAnyActiveSubscription
        isAtelierSubscriber = hasAtelier || hasAtelierProduct
        
        // Determine tier (Atelier > Creator > Studio > Active Sub > Free)
        if hasAtelier || hasAtelierProduct {
            currentTier = .atelier
        } else if hasCreator || hasStudio || hasAnyActiveSubscription {
            currentTier = .creator  // Any active subscription = at least Creator access
        } else {
            currentTier = .free
        }
        
        // Check weekly reset
        checkAndResetWeeklyLooks()
        
        // Log status
        switch currentTier {
        case .atelier:
            print("📊 Tier: ATELIER ✨ (unlimited looks + editorial + creative director)")
        case .creator:
            print("📊 Tier: CREATOR ✅ (\(weeklyLooksRemaining)/20 looks remaining this week)")
            if hasAnyActiveSubscription {
                print("📊 Active subscriptions: \(customerInfo.activeSubscriptions)")
            }
        case .free:
            print("📊 Tier: FREE")
        }
    }
    
    // MARK: - Fetch Offerings
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            print("✅ Fetched offerings: \(offerings.current?.identifier ?? "none")")
        } catch {
            print("❌ Failed to fetch offerings: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Purchase Product (by ID)
    func purchaseProduct(withId identifier: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // 1. Try to find a Package first (better for analytics)
        if let package = findPackage(byProductId: identifier) {
            print("📦 Found package for \(identifier), purchasing...")
            try await purchase(package)
            return
        }
        
        // 2. Fallback: Fetch StoreProduct directly
        print("⚠️ Package not found. Fetching \(identifier) directly from App Store...")
        let products = await Purchases.shared.products([identifier])
        
        guard let product = products.first else {
            errorMessage = "Product not found: \(identifier)"
            throw NSError(domain: "Halo", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found: \(identifier)"])
        }
        
        do {
            let result = try await Purchases.shared.purchase(product: product)
            
            if result.userCancelled {
                throw PurchaseError.cancelled
            }
            
            self.customerInfo = result.customerInfo
            updateSubscriptionStatus(result.customerInfo)
            
            // 🛡️ GUARANTEE: Apple confirmed the purchase → user IS subscribed. Period.
            if !isSubscribed {
                print("🚨 FORCE OVERRIDE: Purchase confirmed by Apple but entitlement missing. Forcing Creator access.")
                isSubscribed = true
                currentTier = .creator
            }
            
            HapticManager.success()
            
            // 🔐 CRITICAL: Transfer anonymous purchase to Supabase user ID
            await syncIdentityAfterPurchase()
            
            handlePurchaseSuccess(
                productId: identifier,
                price: NSDecimalNumber(decimal: product.price).doubleValue,
                productName: product.localizedTitle
            )
            
        } catch PurchaseError.cancelled {
            throw PurchaseError.cancelled
        } catch {
            HapticManager.error()
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Purchase Package
    func purchase(_ package: Package) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if result.userCancelled { throw PurchaseError.cancelled }
            
            self.customerInfo = result.customerInfo
            updateSubscriptionStatus(result.customerInfo)
            
            // 🛡️ GUARANTEE: Apple confirmed the purchase → user IS subscribed. Period.
            if !isSubscribed {
                print("🚨 FORCE OVERRIDE: Purchase confirmed by Apple but entitlement missing. Forcing Creator access.")
                isSubscribed = true
                currentTier = .creator
            }
            
            HapticManager.success()
            print("✅ Purchase successful! Tier: \(currentTier.displayName)")
            
            // 🔐 CRITICAL: Transfer anonymous purchase to Supabase user ID
            await syncIdentityAfterPurchase()
            
            handlePurchaseSuccess(
                productId: package.storeProduct.productIdentifier,
                price: NSDecimalNumber(decimal: package.storeProduct.price).doubleValue,
                productName: package.storeProduct.localizedTitle
            )
            
        } catch PurchaseError.cancelled {
            throw PurchaseError.cancelled
        } catch {
            HapticManager.error()
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Post-Purchase Identity Sync
    /// After a successful purchase, ensure RevenueCat identity is linked to the Supabase user ID.
    /// This handles the case where the user pays on an anonymous RevenueCat ID before creating an account.
    /// Without this, the entitlement stays on $RCAnonymousID and the server can't verify it.
    private func syncIdentityAfterPurchase() async {
        let currentRCUser = Purchases.shared.appUserID
        
        // Case 1: RevenueCat is still anonymous → sync with Supabase user ID
        if currentRCUser.hasPrefix("$RCAnonymousID") {
            if let userId = AuthService.shared.userId {
                print("🔐 Purchase on anonymous RC ID → transferring to Supabase user \(userId)")
                do {
                    let (customerInfo, _) = try await Purchases.shared.logIn(userId)
                    self.customerInfo = customerInfo
                    updateSubscriptionStatus(customerInfo)
                    print("✅ Purchase transferred to \(userId). Tier: \(currentTier.displayName)")
                } catch {
                    print("⚠️ Failed to transfer purchase to user ID: \(error)")
                    // Don't fail the purchase — the restore flow at next app launch will catch it
                }
            } else {
                print("⚠️ Purchase on anonymous RC ID but no Supabase user yet — will sync at login")
            }
        }
        
        // Case 2: RevenueCat already identified → verify entitlement is active
        else {
            print("✅ RevenueCat already identified as \(currentRCUser)")
            // Force refresh to ensure entitlement is reflected
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                self.customerInfo = customerInfo
                updateSubscriptionStatus(customerInfo)
            } catch {
                print("⚠️ Failed to refresh customer info: \(error)")
            }
        }
    }
    
    // MARK: - Purchase Success Handler
    private func handlePurchaseSuccess(productId: String, price: Double, productName: String) {
        // TikTok Analytics
        let isAtelier = productId.contains("atelier")
        let planType: String
        if isAtelier { planType = "atelier_monthly" }
        else if productId.contains("weekly") { planType = "creator_weekly" }
        else { planType = "other" }
        
        TikTokService.shared.trackPurchase(productId: productId, productName: productName, price: price)
        TikTokService.shared.trackSubscribe(planType: planType, price: price)
        
        // Notifications
        NotificationManager.shared.scheduleAfterPurchase(isCreatorMode: true)
        
        // Sync Generation
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                NotificationCenter.default.post(name: .syncGenerationAfterPurchase, object: nil)
            }
        }
    }
    
    // MARK: - Purchase Errors
    enum PurchaseError: LocalizedError {
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .cancelled: return "Purchase was cancelled"
            }
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            updateSubscriptionStatus(customerInfo)
            
            if isSubscribed {
                HapticManager.success()
                print("✅ Purchases restored successfully")
            } else {
                errorMessage = "No active subscription found to restore."
            }
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func restorePurchasesSilently() async {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            updateSubscriptionStatus(customerInfo)
            if isSubscribed {
                print("✅ Subscription recovered via silent restore!")
                HapticManager.success()
            }
        } catch {
            print("⚠️ Silent restore failed (normal if no purchases): \(error)")
        }
    }
    
    // MARK: - Manage Subscription
    func manageSubscription() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Login / Logout
    func login(userID: String) async {
        do {
            let previousRCUser = Purchases.shared.appUserID
            
            // 🚨 CRITICAL FIX: If we're already identified as a DIFFERENT user (e.g. anonymous
            // Supabase UUID_A → real account UUID_B), we must logOut() first.
            // RevenueCat only transfers purchases FROM anonymous → identified.
            // Going from identified_A → identified_B does NOT transfer purchases.
            // By logging out first, the SDK becomes anonymous, and the subsequent
            // logIn(UUID_B) will properly transfer all purchases.
            if !previousRCUser.hasPrefix("$RCAnonymousID") && previousRCUser != userID {
                print("🔄 Switching RC identity: \(previousRCUser) → \(userID)")
                print("🔄 Logging out first to enable purchase transfer...")
                _ = try await Purchases.shared.logOut()
                print("✅ RC now anonymous — ready for logIn transfer")
            }
            
            let (customerInfo, created) = try await Purchases.shared.logIn(userID)
            self.customerInfo = customerInfo
            updateSubscriptionStatus(customerInfo)
            print("👤 RevenueCat logged in: \(userID) (New: \(created), Tier: \(currentTier.displayName), previous: \(previousRCUser))")
            
            // ALWAYS restore after login to transfer purchases
            print("🔄 Restoring purchases after login...")
            let restoredInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = restoredInfo
            updateSubscriptionStatus(restoredInfo)
            print("✅ Purchases restored. Tier: \(currentTier.displayName)")
        } catch {
            print("❌ RevenueCat login failed: \(error)")
        }
    }
    
    func logout() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            updateSubscriptionStatus(customerInfo)
            print("👤 RevenueCat logged out")
        } catch {
            print("❌ RevenueCat logout failed: \(error)")
        }
    }
}

// MARK: - Purchases Delegate
extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.updateSubscriptionStatus(customerInfo)
        }
    }
}
