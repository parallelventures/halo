//
//  SubscriptionManager.swift
//  Halo
//
//  RevenueCat integration for subscription management
//

import Foundation
import RevenueCat

// MARK: - Entitlement IDs
enum EntitlementID {
    static let studio = "Studio"
}

// MARK: - Product IDs
enum ProductID {
    static let monthlySubscription = "monthly"
    static let annualSubscription = "annual"
}

// MARK: - RevenueCat Configuration
struct RevenueCatConfig {
    static let apiKey = "appl_aItvxVcPPogBXOONwvaVHYvBBcN"
}

// MARK: - Subscription Manager
@MainActor
final class SubscriptionManager: NSObject, ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Current offering packages
    var monthlyPackage: Package? {
        offerings?.current?.monthly ?? offerings?.current?.package(identifier: "monthly")
    }
    
    var annualPackage: Package? {
        offerings?.current?.annual ?? offerings?.current?.package(identifier: "annual")
    }
    
    var allPackages: [Package] {
        offerings?.current?.availablePackages ?? []
    }
    
    // Debug mode for testing
    #if DEBUG
    private var debugForceSubscribed = false
    #endif
    
    // MARK: - Init
    override init() {
        super.init()
    }
    
    // MARK: - Configure RevenueCat
    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        Purchases.shared.delegate = self
        
        // Fetch offerings and customer info
        Task {
            await fetchOfferings()
            await refreshCustomerInfo()
        }
    }
    
    // MARK: - Configure with User ID
    func configure(withUserID userID: String) {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey, appUserID: userID)
        Purchases.shared.delegate = self
        
        Task {
            await fetchOfferings()
            await refreshCustomerInfo()
        }
    }
    
    // MARK: - Login User
    func login(userID: String) async {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userID)
            self.customerInfo = customerInfo
            updateSubscriptionStatus(customerInfo)
        } catch {
            print("❌ RevenueCat login error: \(error)")
        }
    }
    
    // MARK: - Logout User
    func logout() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            updateSubscriptionStatus(customerInfo)
        } catch {
            print("❌ RevenueCat logout error: \(error)")
        }
    }
    
    // MARK: - Fetch Offerings
    func fetchOfferings() async {
        isLoading = true
        
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            print("✅ Fetched offerings: \(offerings.current?.identifier ?? "none")")
            print("📦 Packages: \(offerings.current?.availablePackages.map { $0.identifier } ?? [])")
        } catch {
            print("❌ Failed to fetch offerings: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
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
        #if DEBUG
        if debugForceSubscribed {
            isSubscribed = true
            return
        }
        #endif
        
        isSubscribed = customerInfo.entitlements[EntitlementID.studio]?.isActive == true
        print("📊 Subscription status: \(isSubscribed ? "Premium" : "Free")")
    }
    
    // MARK: - Purchase Package
    func purchase(_ package: Package) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                self.customerInfo = result.customerInfo
                updateSubscriptionStatus(result.customerInfo)
                HapticManager.success()
                print("✅ Purchase successful!")
            }
        } catch {
            HapticManager.error()
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Purchase Monthly
    func purchaseMonthly() async throws {
        guard let package = monthlyPackage else {
            throw SubscriptionError.packageNotFound
        }
        try await purchase(package)
    }
    
    // MARK: - Purchase Annual
    func purchaseAnnual() async throws {
        guard let package = annualPackage else {
            throw SubscriptionError.packageNotFound
        }
        try await purchase(package)
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            updateSubscriptionStatus(customerInfo)
            
            if isSubscribed {
                HapticManager.success()
                print("✅ Purchases restored!")
            } else {
                print("ℹ️ No purchases to restore")
            }
        } catch {
            HapticManager.error()
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Debug
    #if DEBUG
    func setDebugSubscribed(_ value: Bool) {
        debugForceSubscribed = value
        isSubscribed = value
    }
    #endif
}

// MARK: - PurchasesDelegate
extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.updateSubscriptionStatus(customerInfo)
        }
    }
}

// MARK: - Subscription Errors
enum SubscriptionError: LocalizedError {
    case packageNotFound
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .packageNotFound:
            return "Subscription package not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}

// MARK: - Price Helpers
extension Package {
    var localizedPricePerMonth: String {
        switch packageType {
        case .annual:
            let monthlyPrice = storeProduct.price as Decimal / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = storeProduct.priceFormatter?.locale
            return formatter.string(from: monthlyPrice as NSDecimalNumber) ?? ""
        default:
            return storeProduct.localizedPriceString
        }
    }
    
    var savingsPercentage: Int? {
        guard packageType == .annual else { return nil }
        // Calculate savings compared to monthly
        // This is a rough estimate - in production you'd compare actual prices
        return 40 // ~40% savings for annual
    }
}
