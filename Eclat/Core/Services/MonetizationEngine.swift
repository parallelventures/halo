//
//  MonetizationEngine.swift
//  Eclat
//
//  Top-tier monetization decision engine
//  Server-driven offers with local fallbacks
//

import Foundation

// MARK: - User Segment
enum UserSegment: String, Codable {
    case tourist = "TOURIST"
    case sampler = "SAMPLER"
    case explorer = "EXPLORER"
    case buyer = "BUYER"
    case power = "POWER"
    
    var displayName: String {
        switch self {
        case .tourist: return "Tourist"
        case .sampler: return "Sampler"
        case .explorer: return "Explorer"
        case .buyer: return "Buyer"
        case .power: return "Power User"
        }
    }
}

// MARK: - Offer Type
enum OfferKey: String, Codable {
    case entry = "entry"
    case packs = "packs"
    case creatorMode = "creator_mode"
}

// MARK: - Surface Type
enum OfferSurface: String, Codable {
    case sheet = "sheet"
    case fullscreen = "fullscreen"
    case pill = "pill"
    case card = "card"
}

// MARK: - Copy Variant
struct CopyVariant: Codable {
    let title: String
    let subtitle: String?
    let bullets: [String]?
    let cta: String
    let secondary: String?
    let footnote: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        bullets: [String]? = nil,
        cta: String,
        secondary: String? = nil,
        footnote: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.bullets = bullets
        self.cta = cta
        self.secondary = secondary
        self.footnote = footnote
    }
}

// MARK: - Product Info
struct ProductInfo: Codable, Identifiable {
    let id: String
    let price: String
    let looksGranted: Int?
    let label: String?
    let subtitle: String?
    let badge: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case price
        case looksGranted = "looks_granted"
        case label
        case subtitle
        case badge
    }
}

// MARK: - Offer Decision
struct OfferDecision: Codable {
    let shouldShow: Bool
    let offerKey: OfferKey?
    let surface: OfferSurface?
    let products: [ProductInfo]?
    let highlight: String?
    let copyVariant: CopyVariant?
    let segment: UserSegment?
    let looksBalance: Int?
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case shouldShow = "should_show"
        case offerKey = "offer_key"
        case surface
        case products
        case highlight
        case copyVariant = "copy_variant"
        case segment
        case looksBalance = "looks_balance"
        case reason
    }
}

// MARK: - Monetization Event
enum MonetizationEvent: String {
    case appOpen = "app_open"
    case tryGenerate = "try_generate"
    case generationSuccess = "generation_success"
    case generationFailed = "generation_failed"
    case outOfLooks = "out_of_looks"
    case saveResult = "save_result"
    case shareResult = "share_result"
    case attemptSecondPack = "attempt_second_pack"
}

// MARK: - Monetization Engine
@MainActor
final class MonetizationEngine: ObservableObject {
    
    static let shared = MonetizationEngine()
    
    // MARK: - Published Properties
    @Published private(set) var currentSegment: UserSegment = .tourist
    @Published private(set) var lastDecision: OfferDecision?
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Local tracking (for fallbacks)
    private var localImpressionTimestamps: [OfferKey: Date] = [:]
    private var dailyImpressionCount: Int = 0
    private var lastImpressionDate: Date?
    
    // MARK: - Constants
    private let sameOfferCooldownHours: Int = 24
    private let anyOfferCooldownHours: Int = 4
    private let maxDailyImpressions: Int = 2
    
    // MARK: - Init
    private init() {
        loadLocalState()
    }
    
    // MARK: - Decide Next Offer (Server-driven)
    func decideOffer(
        for event: MonetizationEvent,
        context: [String: Any] = [:]
    ) async -> OfferDecision {
        isLoading = true
        defer { isLoading = false }
        
        // Try server-side decision first
        do {
            let decision = try await fetchServerDecision(event: event, context: context)
            lastDecision = decision
            
            if decision.shouldShow, let segment = decision.segment {
                currentSegment = segment
            }
            
            return decision
        } catch {
            print("⚠️ Server decision failed, using local fallback: \(error)")
            return localFallbackDecision(for: event)
        }
    }
    
    // MARK: - Record Impression
    func recordImpression(offerKey: OfferKey, surface: OfferSurface, action: String? = nil) async {
        // Record locally
        localImpressionTimestamps[offerKey] = Date()
        updateDailyCount()
        saveLocalState()
        
        // Record to server
        guard SupabaseService.shared.currentUser != nil else { return }
        
        do {
            let body: [String: Any] = [
                "offer_key": offerKey.rawValue,
                "surface": surface.rawValue,
                "action_taken": action as Any
            ]
            
            _ = try await callEdgeFunction(name: "record-impression", body: body)
            print("✅ Impression recorded: \(offerKey.rawValue) on \(surface.rawValue)")
        } catch {
            print("❌ Failed to record impression: \(error)")
        }
    }
    
    // MARK: - Check Local Cooldown
    func isOnCooldown(for offerKey: OfferKey) -> Bool {
        // Check daily limit
        if dailyImpressionCount >= maxDailyImpressions {
            return true
        }
        
        // Check same offer cooldown
        if let lastTime = localImpressionTimestamps[offerKey] {
            let hoursSince = Date().timeIntervalSince(lastTime) / 3600
            if hoursSince < Double(sameOfferCooldownHours) {
                return true
            }
        }
        
        // Check any offer cooldown
        let mostRecent = localImpressionTimestamps.values.max()
        if let mostRecent = mostRecent {
            let hoursSince = Date().timeIntervalSince(mostRecent) / 3600
            if hoursSince < Double(anyOfferCooldownHours) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Get Segment-Based Copy
    func getCopyVariant(for offerKey: OfferKey) -> CopyVariant {
        switch (currentSegment, offerKey) {
        case (.tourist, .entry):
            return CopyVariant(
                title: "Unlock your first looks",
                subtitle: "Preview your next hairstyle on you — instantly.",
                bullets: ["Realistic results", "Made to look like you", "Save & share"],
                cta: "Unlock for $2.99",
                footnote: "One-time purchase. No subscription."
            )
            
        case (.tourist, .packs), (.sampler, .packs):
            return CopyVariant(
                title: "You're out of looks",
                subtitle: "Keep exploring — your next look is one tap away.",
                cta: "Get 30 Looks",
                footnote: "Looks never expire."
            )
            
        case (.sampler, .creatorMode):
            return CopyVariant(
                title: "Creator Mode",
                subtitle: "Create freely — without interruptions.",
                bullets: ["Unlimited looks", "Studio-grade quality", "No watermark"],
                cta: "Enter Creator Mode — $12.99/week",
                secondary: "Or get more looks",
                footnote: "Renews weekly. Cancel anytime."
            )
            
        case (.explorer, .creatorMode):
            return CopyVariant(
                title: "Creator Mode",
                subtitle: "You're exploring deeply. Don't count looks.",
                bullets: ["Unlimited looks", "Studio-grade quality", "No watermark"],
                cta: "Enter Creator Mode — $12.99/week",
                secondary: "Buy looks instead",
                footnote: "Most users choose Creator Mode once they start comparing."
            )
            
        case (.buyer, .creatorMode):
            return CopyVariant(
                title: "Make it effortless",
                subtitle: "You're buying looks often. Creator Mode is simpler.",
                bullets: ["Unlimited looks", "Studio-grade quality", "No watermark"],
                cta: "Enter Creator Mode — $12.99/week",
                secondary: "Continue with packs"
            )
            
        case (.power, .creatorMode):
            return CopyVariant(
                title: "Stay in flow",
                subtitle: "Unlimited creation, no interruptions.",
                cta: "Enter Creator Mode",
                secondary: "Not now"
            )
            
        default:
            return CopyVariant(
                title: "Get more looks",
                cta: "Continue"
            )
        }
    }
    
    // MARK: - Private: Server Decision
    private func fetchServerDecision(event: MonetizationEvent, context: [String: Any]) async throws -> OfferDecision {
        var body: [String: Any] = ["event": event.rawValue]
        if !context.isEmpty {
            body["context"] = context
        }
        
        let response = try await callEdgeFunction(name: "decide-offer", body: body)
        
        let jsonData = try JSONSerialization.data(withJSONObject: response)
        let decoder = JSONDecoder()
        return try decoder.decode(OfferDecision.self, from: jsonData)
    }
    
    // MARK: - Private: Local Fallback Decision
    private func localFallbackDecision(for event: MonetizationEvent) -> OfferDecision {
        let subscriptionManager = SubscriptionManager.shared
        
        // 🚨 IMPORTANT: outOfLooks should NEVER be blocked by cooldown
        // The user has no credits - they MUST see a paywall to continue
        // Cooldown only applies to upsell moments, not blocking moments
        
        switch event {
        case .tryGenerate:
            if !subscriptionManager.isSubscribed {
                return OfferDecision(
                    shouldShow: true,
                    offerKey: .entry,
                    surface: .sheet,
                    products: nil,
                    highlight: "subscribe",
                    copyVariant: getCopyVariant(for: .entry),
                    segment: .tourist,
                    looksBalance: 0,
                    reason: nil
                )
            }
            
        case .outOfLooks:
            if subscriptionManager.isSubscribed {
                // Subscriber who ran out of weekly looks → show Creator Mode upsell
                return OfferDecision(
                    shouldShow: true,
                    offerKey: .creatorMode,
                    surface: .sheet,
                    products: nil,
                    highlight: "creator_mode_weekly",
                    copyVariant: CopyVariant(
                        title: "You've used your weekly looks.",
                        subtitle: "Upgrade for unlimited looks.",
                        bullets: ["Unlimited looks", "Studio-grade quality", "No watermark", "Priority generations"],
                        cta: "Upgrade to Atelier",
                        secondary: nil,
                        footnote: "Unlimited looks • Cancel anytime"
                    ),
                    segment: currentSegment,
                    looksBalance: 0,
                    reason: nil
                )
            } else {
                // Free user → show subscription
                return OfferDecision(
                    shouldShow: true,
                    offerKey: .entry,
                    surface: .sheet,
                    products: nil,
                    highlight: "subscribe",
                    copyVariant: getCopyVariant(for: .entry),
                    segment: .tourist,
                    looksBalance: 0,
                    reason: nil
                )
            }
            
        case .saveResult, .shareResult:
            if subscriptionManager.isSubscribed && !isOnCooldown(for: .creatorMode) {
                return OfferDecision(
                    shouldShow: true,
                    offerKey: .creatorMode,
                    surface: .pill,
                    products: nil,
                    highlight: "creator_mode_weekly",
                    copyVariant: CopyVariant(
                        title: "Create freely this week",
                        cta: "Try Creator Mode"
                    ),
                    segment: currentSegment,
                    looksBalance: subscriptionManager.weeklyLooksRemaining,
                    reason: nil
                )
            }
            
        default:
            break
        }
        
        return OfferDecision(
            shouldShow: false,
            offerKey: nil,
            surface: nil,
            products: nil,
            highlight: nil,
            copyVariant: nil,
            segment: currentSegment,
            looksBalance: subscriptionManager.weeklyLooksRemaining,
            reason: "no_offer"
        )
    }
    
    // MARK: - Private: Edge Function Call
    private func callEdgeFunction(name: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/functions/v1/\(name)") else {
            throw MonetizationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "apikey")
        
        if let token = AuthService.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MonetizationError.serverError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MonetizationError.invalidResponse
        }
        
        return json
    }
    
    // MARK: - Private: Local State Persistence
    private func loadLocalState() {
        if let data = UserDefaults.standard.data(forKey: "monetization_impressions"),
           let timestamps = try? JSONDecoder().decode([String: Date].self, from: data) {
            localImpressionTimestamps = timestamps.compactMapKeys { OfferKey(rawValue: $0) }
        }
        
        dailyImpressionCount = UserDefaults.standard.integer(forKey: "monetization_daily_count")
        lastImpressionDate = UserDefaults.standard.object(forKey: "monetization_last_date") as? Date
        
        // Reset daily count if new day
        if let lastDate = lastImpressionDate, !Calendar.current.isDateInToday(lastDate) {
            dailyImpressionCount = 0
        }
    }
    
    private func saveLocalState() {
        let stringKeys = localImpressionTimestamps.mapKeys { $0.rawValue }
        if let data = try? JSONEncoder().encode(stringKeys) {
            UserDefaults.standard.set(data, forKey: "monetization_impressions")
        }
        UserDefaults.standard.set(dailyImpressionCount, forKey: "monetization_daily_count")
        UserDefaults.standard.set(Date(), forKey: "monetization_last_date")
    }
    
    private func updateDailyCount() {
        if let lastDate = lastImpressionDate, !Calendar.current.isDateInToday(lastDate) {
            dailyImpressionCount = 1
        } else {
            dailyImpressionCount += 1
        }
        lastImpressionDate = Date()
    }
}

// MARK: - Errors
enum MonetizationError: LocalizedError {
    case invalidURL
    case serverError
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError: return "Server error"
        case .invalidResponse: return "Invalid response"
        }
    }
}

// MARK: - Dictionary Extension
extension Dictionary {
    func compactMapKeys<T>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
    
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
