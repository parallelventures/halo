    // MARK: - Handle Purchase
    private func handlePurchase() async {
        print("🔥 handlePurchase() started")
        isPurchasing = true
        
        if subscriptionManager.offerings == nil || subscriptionManager.allPackages.isEmpty {
            await subscriptionManager.fetchOfferings()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        let package = subscriptionManager.weeklyPackage ?? subscriptionManager.monthlyPackage
        
        guard let package = package else {
            print("🔥 ❌ No package found")
            subscriptionManager.errorMessage = "Unable to load purchase. Please try again."
            isPurchasing = false
            return
        }
        
        print("🔥 Package: \(package.storeProduct.productIdentifier)")
        TikTokService.shared.trackCheckoutInitiated(planType: "entry", price: 2.99)
        
        do {
            print("🔥 Calling purchase()...")
            try await subscriptionManager.purchase(package)
            print("🔥 ✅ Purchase SUCCESS!")
            
            // Track purchase
            TikTokService.shared.trackPurchase(
                productId: package.storeProduct.productIdentifier,
                productName: "Eclat Entry",
                price: 2.99,
                currency: "USD"
            )
            HapticManager.success()
            
            // FORCE close paywall and navigate
            await MainActor.run {
                print("🔥 Closing paywall and navigating...")
                appState.showPaywallSheet = false
                appState.navigateTo(.auth)
                print("🔥 Done!")
            }
            
        } catch {
            print("🔥 ❌ Purchase failed: \(error)")
            TikTokService.shared.trackPaywallDismissed(selectedPlan: "entry")
            if subscriptionManager.errorMessage == nil {
                subscriptionManager.errorMessage = "Purchase failed. Please try again."
            }
        }
        
        isPurchasing = false
    }
