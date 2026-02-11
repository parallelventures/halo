//
//  CreditsService.swift
//  Eclat
//
//  Centralized service for managing Looks credits via Supabase
//  Scalable, atomic, multi-device sync
//

import Foundation

@MainActor
final class CreditsService: ObservableObject {
    
    static let shared = CreditsService()
    
    // MARK: - Published Properties
    @Published private(set) var balance: Int = 0
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Daily Limit (Hard cap to protect LTV)
    private let dailyGenerationLimit = 20
    @Published private(set) var dailyGenerationCount: Int = 0
    @Published private(set) var dailyLimitResetTime: Date?
    
    /// Whether user has any Looks available
    var hasLooks: Bool {
        balance > 0
    }
    
    /// Whether user has reached daily generation limit (20/day)
    var hasReachedDailyLimit: Bool {
        dailyGenerationCount >= dailyGenerationLimit
    }
    
    /// Remaining generations today
    var remainingGenerationsToday: Int {
        max(0, dailyGenerationLimit - dailyGenerationCount)
    }
    
    /// Time until daily reset (formatted)
    var timeUntilReset: String {
        guard let resetTime = dailyLimitResetTime else { return "soon" }
        let remaining = resetTime.timeIntervalSinceNow
        if remaining <= 0 { return "now" }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    // MARK: - Init
    private init() {
        // Load cached balance first
        loadCachedBalance()
        loadDailyLimitState()
    }
    
    // MARK: - Fetch Balance from Supabase
    func fetchBalance() async {
        guard SupabaseService.shared.currentUser != nil else {
            print("💎 Credits: No user logged in, using cached balance")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await callEdgeFunction(name: "get-credits", body: [:])
            
            if let newBalance = response["balance"] as? Int {
                balance = newBalance
                cacheBalance(newBalance)
                print("💎 Credits fetched from Supabase: \(balance)")
            }
        } catch {
            print("❌ Failed to fetch credits: \(error)")
            // Keep using cached balance
        }
    }
    
    // MARK: - Add Credits (after purchase)
    func addCredits(_ amount: Int) async -> Bool {
        // 🚨 CRITICAL FIX: Check if user is anonymous OR not authenticated
        // Anonymous users should queue credits for sync after real auth
        let isAnonymous = AuthService.shared.isAnonymous
        let hasUser = SupabaseService.shared.currentUser != nil
        
        guard hasUser && !isAnonymous else {
            // No user OR anonymous user - add locally and queue for sync
            balance += amount
            cacheBalance(balance)
            
            // Queue for sync after real auth (Apple/Google sign in)
            let currentPending = UserDefaults.standard.integer(forKey: "pending_credits_sync")
            let newPending = currentPending + amount
            UserDefaults.standard.set(newPending, forKey: "pending_credits_sync")
            
            let reason = !hasUser ? "no user" : "anonymous user"
            print("💎 Credits added locally (\(reason)): \(amount), total: \(balance). Queued for sync (pending: \(newPending)).")
            return true
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await callEdgeFunction(
                name: "add-credits",
                body: ["amount": amount]
            )
            
            if let success = response["success"] as? Bool, success,
               let newBalance = response["new_balance"] as? Int {
                balance = newBalance
                cacheBalance(newBalance)
                print("💎 Credits added via Supabase: +\(amount), total: \(balance)")
                return true
            }
        } catch {
            print("❌ Failed to add credits via Supabase: \(error)")
            // Fallback: add locally AND queue for sync (server call failed)
            balance += amount
            cacheBalance(balance)
            
            // Queue for retry on next sync
            let currentPending = UserDefaults.standard.integer(forKey: "pending_credits_sync")
            let newPending = currentPending + amount
            UserDefaults.standard.set(newPending, forKey: "pending_credits_sync")
            
            print("💎 Credits added locally (server error), queued for sync: \(newPending)")
            return true
        }
        
        return false
    }
    
    // MARK: - Spend 1 Credit (before generation)
    func spendCredit() async -> Bool {
        guard balance > 0 else {
            print("❌ No credits to spend")
            return false
        }
        
        guard SupabaseService.shared.currentUser != nil else {
            // No user - spend locally
            balance -= 1
            cacheBalance(balance)
            print("💎 Credit spent locally (no user), remaining: \(balance)")
            return true
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await callEdgeFunction(name: "spend-credit", body: [:])
            
            if let success = response["success"] as? Bool, success,
               let newBalance = response["new_balance"] as? Int {
                balance = newBalance
                cacheBalance(newBalance)
                print("💎 Credit spent via Supabase, remaining: \(balance)")
                return true
            } else if let error = response["error"] as? String {
                errorMessage = error
                // Refresh balance in case of desync
                await fetchBalance()
                return false
            }
        } catch {
            print("❌ Failed to spend credit: \(error)")
            // Fallback: spend locally (risky but keeps UX working)
            balance -= 1
            cacheBalance(balance)
            return true
        }
        
        return false
    }
    
    // MARK: - Sync Credits (call after real auth - Apple/Google)
    func syncAfterAuth() async {
        // 🚨 CRITICAL: Only sync if user is ACTUALLY authenticated (not anonymous)
        guard !AuthService.shared.isAnonymous else {
            print("💎 syncAfterAuth skipped - user is still anonymous")
            return
        }
        
        guard SupabaseService.shared.currentUser != nil else {
            print("💎 syncAfterAuth skipped - no Supabase user")
            return
        }
        
        // 1. Check for pending credits purchased while anonymous
        let pending = UserDefaults.standard.integer(forKey: "pending_credits_sync")
        print("💎 DEBUG: syncAfterAuth check - pending = \(pending), isAnonymous = \(AuthService.shared.isAnonymous)")
        
        if pending > 0 {
            print("💎 Found \(pending) pending credits to sync to authenticated user...")
            
            do {
                let response = try await callEdgeFunction(
                    name: "add-credits",
                    body: ["amount": pending]
                )
                
                if let success = response["success"] as? Bool, success,
                   let newBalance = response["new_balance"] as? Int {
                    print("✅ Pending credits synced successfully! New balance: \(newBalance)")
                    // Clear pending
                    UserDefaults.standard.set(0, forKey: "pending_credits_sync")
                    // Update local balance immediately
                    balance = newBalance
                    cacheBalance(newBalance)
                } else if let error = response["error"] as? String {
                    print("❌ Server rejected credit sync: \(error)")
                }
            } catch {
                print("❌ Failed to sync pending credits: \(error)")
                // Keep pending for retry later
            }
        } else {
            print("💎 No pending credits to sync")
        }
        
        // 2. Fetch fresh balance from server (ensures consistency)
        await fetchBalance()
    }
    
    // MARK: - Private: Cache Management
    private func loadCachedBalance() {
        balance = UserDefaults.standard.integer(forKey: "cached_looks_balance")
        print("💎 Loaded cached credits: \(balance)")
    }
    
    private func cacheBalance(_ value: Int) {
        UserDefaults.standard.set(value, forKey: "cached_looks_balance")
    }
    
    // MARK: - Private: Edge Function Call
    private func callEdgeFunction(name: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/functions/v1/\(name)") else {
            throw CreditsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        // Add auth token if user is logged in
        if let token = AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else {
            request.httpBody = "{}".data(using: .utf8)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CreditsError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 402 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CreditsError.serverError(errorBody)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CreditsError.invalidResponse
        }
        
        return json
    }
    
    // MARK: - Daily Limit Functions (Server-side with local fallback)
    
    /// Check daily limit from server
    func checkDailyLimitFromServer() async {
        guard SupabaseService.shared.currentUser != nil else {
            // No user - use local check
            checkAndResetDailyLimit()
            return
        }
        
        do {
            let response = try await callEdgeFunction(name: "check-daily-limit", body: ["action": "check"])
            
            if let count = response["count"] as? Int,
               let canGenerate = response["can_generate"] as? Bool {
                dailyGenerationCount = count
                
                if !canGenerate {
                    // Parse reset time from server
                    if let resetMinutes = response["reset_in_minutes"] as? Int, resetMinutes > 0 {
                        dailyLimitResetTime = Calendar.current.date(byAdding: .minute, value: resetMinutes, to: Date())
                    }
                } else {
                    dailyLimitResetTime = nil
                }
                
                // Cache locally
                saveDailyLimitState()
                print("📊 Server daily limit: \(dailyGenerationCount)/\(dailyGenerationLimit)")
            }
        } catch {
            print("⚠️ Failed to check daily limit from server: \(error)")
            // Fallback to local
            loadDailyLimitState()
        }
    }
    
    /// Record a generation (uses server count via generations table)
    /// Server automatically counts from generations table
    func recordGeneration() {
        // Server counts generations automatically from the generations table
        // Just increment local cache for immediate UI feedback
        dailyGenerationCount += 1
        
        if dailyLimitResetTime == nil {
            dailyLimitResetTime = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        }
        
        saveDailyLimitState()
        print("📊 Daily generation recorded: \(dailyGenerationCount)/\(dailyGenerationLimit)")
    }
    
    /// Check if daily limit should reset (local fallback)
    func checkAndResetDailyLimit() {
        if let resetTime = dailyLimitResetTime, Date() >= resetTime {
            dailyGenerationCount = 0
            dailyLimitResetTime = nil
            saveDailyLimitState()
            print("🔄 Daily limit reset!")
        }
    }
    
    private func loadDailyLimitState() {
        dailyGenerationCount = UserDefaults.standard.integer(forKey: "daily_generation_count")
        dailyLimitResetTime = UserDefaults.standard.object(forKey: "daily_limit_reset_time") as? Date
        checkAndResetDailyLimit()
    }
    
    private func saveDailyLimitState() {
        UserDefaults.standard.set(dailyGenerationCount, forKey: "daily_generation_count")
        UserDefaults.standard.set(dailyLimitResetTime, forKey: "daily_limit_reset_time")
    }
}

// MARK: - Errors
enum CreditsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case insufficientCredits
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .invalidResponse: return "Invalid server response"
        case .serverError(let msg): return msg
        case .insufficientCredits: return "No credits available"
        }
    }
}
