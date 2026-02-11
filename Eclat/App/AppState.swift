//
//  AppState.swift
//  Eclat
//
//  Global app state management using @Observable pattern
//

import SwiftUI
import Combine

// MARK: - Color Category (Moved here for scope visibility)
enum HairColorCategory: String, CaseIterable, Codable {
    case safe = "Natural"
    case premium = "Premium"
    case bold = "Bold"
}

// MARK: - Hair Color Model (Moved here for scope visibility)
struct HairColor: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let imageName: String 
    let category: HairColorCategory
    let promptModifier: String
    
    var isNew: Bool {
        return category == .bold
    }
}

// MARK: - Screen Enum
enum AppScreen: String, Equatable {
    case splash
    case onboarding
    case processing
    case result
    // case loveYourLook removed - no longer needed
    case paywall
    case creditsPaywall
    case auth  // Authentication after payment
    case home
}

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentScreen: AppScreen = .splash
    @Published var hasCompletedOnboarding: Bool = false
    @Published var capturedImage: UIImage?
    @Published var generatedImage: UIImage?
    @Published var selectedHairstyle: Hairstyle?
    @Published var selectedColor: HairColor? // New for Color Styles
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showCameraSheet: Bool = false
    @Published var showHistorySheet: Bool = false
    @Published var showAuthSheet: Bool = false  // Sign in sheet for unauthenticated users
    @Published var showPaywallSheet: Bool = false
    @Published var showPostPaywallOnboarding: Bool = false
    @Published var isSimulationMode: Bool = false // Safety flag to prevent API costs
    @Published var userGender: StyleCategory = .women
    
    // MARK: - Monetization Engine Integration
    @Published var currentOfferDecision: OfferDecision?
    @Published var showSegmentedPaywall: Bool = false
    
    // MARK: - Processing Session ID (Forces view recreation)
    @Published var processingSessionId: Int = 0
    
    // MARK: - Daily Limit (8 generations / 24h)
    @Published var showDailyLimitReached: Bool = false
    @Published var dailyLimitResetTime: String = ""
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastScreen = "lastScreen"
    }
    
    // MARK: - Init
    init() {
        loadPersistedState()
        setupNotifications()
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .syncGenerationAfterPurchase,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.syncCurrentGeneration()
            }
        }
    }
    
    // MARK: - State Persistence
    private func loadPersistedState() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
        
        // Load user gender preference
        if let savedGender = OnboardingDataService.shared.getStyleCategory() {
            userGender = savedGender
        }
    }
    
    func performBootSequence() async {
        // 🚨 CRITICAL: Always ensure real generation mode at boot
        // This fixes the issue for users who already completed onboarding with the bug
        isSimulationMode = false
        
        // Artificial delay for splash screen
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        
        // Restore last screen intelligently
        if let lastScreenRaw = UserDefaults.standard.string(forKey: Keys.lastScreen),
           let lastScreen = AppScreen(rawValue: lastScreenRaw) {
            
            // Only restore persistent screens, not temporary ones
            switch lastScreen {
            case .home:
                // Only home is safely restorable without image state
                navigateTo(lastScreen)
                return
            case .auth:
                // If user was authenticating, go back to auth
                navigateTo(.auth)
                return
            default:
                // For splash, onboarding, processing, paywall: use normal flow
                break
            }
        }
        
        // Default boot flow
        let destination: AppScreen = hasCompletedOnboarding ? .home : .onboarding
        navigateTo(destination)
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
        
        // 🚨 CRITICAL: Reset simulation mode after onboarding
        isSimulationMode = false
        
        // Track onboarding completion with TikTok
        TikTokService.shared.trackCompleteTutorial()
        
        navigateTo(.home)
        showCameraSheet = true
    }
    
    
    // MARK: - Navigation
    func navigateTo(_ screen: AppScreen) {
        print("🧭 navigateTo: \(screen)")
        
        // DON'T navigate to paywall via this method - use showPaywall() instead
        if screen == .paywall {
            print("⚠️ Use showPaywall() instead of navigateTo(.paywall)")
            showPaywall()
            return
        }
        
        // If navigating to home, ensure onboarding is marked as complete
        if screen == .home && !hasCompletedOnboarding {
            completeOnboarding()
        }
        
        // 🚨 CRITICAL: Increment session ID when navigating to processing
        // This forces ProcessingView to recreate and run startProcessing() fresh
        if screen == .processing {
            processingSessionId += 1
            print("🔄 Processing session ID: \(processingSessionId)")
        }
        
        withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
            currentScreen = screen
        }
        
        // Save to UserDefaults for session restoration
        UserDefaults.standard.set(screen.rawValue, forKey: Keys.lastScreen)
    }
    
    // MARK: - Paywall Control
    func showPaywall() {
        print("💳 Opening paywall")
        showPaywallSheet = true
    }
    
    func closePaywall() {
        print("💳 Closing paywall")
        showPaywallSheet = false
        showSegmentedPaywall = false
        currentOfferDecision = nil
        
        // If user was on processing screen and closed paywall without purchasing,
        // navigate to auth so they create an account for future sync
        if currentScreen == .processing {
            print("⚠️ User closed paywall from processing - redirecting to auth for account creation")
            navigateTo(.auth)
        }
    }
    
    /// Server-driven paywall that shows the right offer based on segment + cooldowns
    func showSmartPaywall(for event: MonetizationEvent) {
        print("🧠 Smart paywall triggered for event: \(event.rawValue)")
        
        Task { @MainActor in
            let decision = await MonetizationEngine.shared.decideOffer(for: event)
            
            if decision.shouldShow, let offerKey = decision.offerKey {
                print("✅ Showing offer: \(offerKey.rawValue) on \(decision.surface?.rawValue ?? "sheet")")
                currentOfferDecision = decision
                showSegmentedPaywall = true
            } else {
                print("⏭️ No offer to show, reason: \(decision.reason ?? "unknown")")
                
                // If no offer due to cooldown but event is out_of_looks, still need to show something
                if event == .outOfLooks {
                    showPaywall()
                }
            }
        }
    }
    
    func forceClosePaywallAndNavigateToAuth() {
        print("⚡️ FORCE CLOSE PAYWALL & AUTH")
        
        Task { @MainActor in
            // 1. Close the sheet
            showPaywallSheet = false
            showSegmentedPaywall = false
            currentOfferDecision = nil
            
            // 2. Wait for dismissal animation
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
            
            print("⚡️ Navigating to Auth now...")
            self.navigateTo(.auth)
        }
    }
    
    // MARK: - Image Handling
    func setCapturedImage(_ image: UIImage) {
        capturedImage = image
        showCameraSheet = false  // Close the sheet first
        
        // 🚨 CRITICAL FIX: Do NOT navigate to processing if we are in Onboarding
        // In onboarding, the view observes 'capturedImage' and handles its own flow (to fake processing)
        if currentScreen != .onboarding {
            navigateTo(.processing)
        } else {
            print("📸 Image captured in Onboarding - staying on screen to let OnboardingView handle flow")
        }
    }
    
    func setGeneratedImage(_ image: UIImage) {
        generatedImage = image
        
        // Auto-sync to Supabase if user is authenticated
        Task {
            await syncCurrentGeneration()
        }
        
        navigateTo(.result)
    }
    
    // MARK: - Sync Generation to Supabase
    @MainActor
    func syncCurrentGeneration() async {
        print("🔍 syncCurrentGeneration called")
        print("   - currentUser: \(SupabaseService.shared.currentUser?.id.uuidString ?? "nil")")
        print("   - capturedImage: \(capturedImage != nil)")
        print("   - generatedImage: \(generatedImage != nil)")
        print("   - selectedHairstyle: \(selectedHairstyle?.name ?? "nil")")
        
        // Only sync if user is authenticated
        guard SupabaseService.shared.currentUser != nil else {
            print("⏭️ Skipping generation sync - user not authenticated yet")
            return
        }
        
        // Check we have all required data
        guard let capturedImage = capturedImage,
              let generatedImage = generatedImage,
              let hairstyle = selectedHairstyle else {
            print("⚠️ Missing data for generation sync - cannot proceed")
            return
        }
        
        print("🔄 Syncing generation to Supabase...")
        
        // Create generation record
        if let generation = await GenerationService.shared.createGeneration(
            originalImage: capturedImage,
            styleName: hairstyle.name,
            styleCategory: hairstyle.category.rawValue,
            stylePrompt: nil // Use optimized prompt from service
        ) {
            // Update with result
            let success = await GenerationService.shared.updateGenerationResult(
                generationId: generation.id,
                generatedImage: generatedImage,
                processingTimeMs: 0
            )
            
            if success {
                print("✅ Generation synced successfully")
            } else {
                print("❌ Failed to sync generation result")
            }
        } else {
            print("❌ Failed to create generation record")
        }
    }
    
    // MARK: - Reset
    func reset() {
        capturedImage = nil
        generatedImage = nil
        selectedHairstyle = nil
        selectedColor = nil
        errorMessage = nil
        isSimulationMode = false // 🚨 Always ensure real generation mode
    }
    
    func startNewTryOn() {
        reset()
        navigateTo(.home)
        showCameraSheet = true
    }
}

// MARK: - Hairstyle Models

enum GenderCategory: String, CaseIterable, Identifiable {
    case women = "Women"
    case men = "Men"
    var id: String { rawValue }
}

enum HairLength: String, CaseIterable, Identifiable {
    case buzz = "Buzz"
    case short = "Short"
    case medium = "Medium"
    case long = "Long"
    var id: String { rawValue }
}

enum HairTexture: String, CaseIterable, Identifiable {
    case straight = "Straight"
    case wavy = "Wavy"
    case curly = "Curly"
    case coily = "Coily"
    var id: String { rawValue }
}

struct Hairstyle: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: GenderCategory
    let length: HairLength
    let texture: HairTexture?
    let tags: [String]
    let description: String
    let imageName: String?
    
    var prompt: String {
        var promptText = "Transform the person's hairstyle to a \(name)"
        if let texture = texture {
            promptText += " with \(texture.rawValue.lowercased()) texture"
        }
        promptText += ". \(description) Keep the face exactly the same, only change the hair. Maintain natural skin tone and facial features."
        return promptText
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Hairstyle, rhs: Hairstyle) -> Bool {
        lhs.id == rhs.id
    }
}

enum HairstyleData {
    static var all: [Hairstyle] { women + men }
    
    static func styles(for category: GenderCategory) -> [Hairstyle] {
        let allStyles: [Hairstyle]
        switch category {
        case .women: allStyles = women
        case .men: allStyles = men
        }
        
        // Filter: only styles with images + remove duplicates by name
        var seen = Set<String>()
        return allStyles.filter { style in
            guard style.imageName != nil else { return false }
            guard !seen.contains(style.name) else { return false }
            seen.insert(style.name)
            return true
        }
    }
    
    static func featuredStyles(for category: GenderCategory, limit: Int = 6) -> [Hairstyle] {
        let styles = self.styles(for: category)
        let featured = styles.filter { $0.tags.contains("trendy") || $0.tags.contains("popular") || $0.tags.contains("iconic") }
        return Array(featured.prefix(limit))
    }
    
    static let women: [Hairstyle] = [
        // MARK: - Identity Shift (The "Dream Self")
        Hairstyle(name: "Clean Girl Bun", category: .women, length: .medium, texture: .straight, tags: ["identity", "clean-girl", "trending", "iconic"], description: "The viral sleek bun. Perfectly polished, minimal, and expensive looking.", imageName: "sleek-bun"),
        Hairstyle(name: "Old Money Bob", category: .women, length: .short, texture: .wavy, tags: ["identity", "luxury", "trending", "popular"], description: "Expensive looking volume bob with bouncy layers.", imageName: "italian-bob"),
        Hairstyle(name: "Glass Hair", category: .women, length: .long, texture: .straight, tags: ["identity", "viral", "sleek"], description: "Mirror-shine straight hair. The ultimate healthy hair flex.", imageName: "glass-hair"),
        Hairstyle(name: "Parisian Muse", category: .women, length: .medium, texture: .wavy, tags: ["identity", "chic", "popular"], description: "Effortless bottleneck bangs and lived-in texture.", imageName: "bottleneck-bangs"),
        
        // MARK: - TikTok / Viral (Social Proof)
        Hairstyle(name: "90s Blowout", category: .women, length: .long, texture: .wavy, tags: ["tiktok", "volume", "iconic", "hot"], description: "Cindy Crawford era volume. Big, bouncy, and glamorous.", imageName: "90s-blowout"),
        Hairstyle(name: "Butterfly Cut", category: .women, length: .long, texture: .wavy, tags: ["tiktok", "viral", "layered"], description: "Face-framing layers with maximum volume and movement.", imageName: "butterfly-cut"),
        Hairstyle(name: "Mob Wife Waves", category: .women, length: .long, texture: .wavy, tags: ["tiktok", "glam", "volume"], description: "Messy, unapologetic luxury volume. Big hair energy.", imageName: "hollywood-waves"),
        Hairstyle(name: "Claw Clip Chic", category: .women, length: .medium, texture: .wavy, tags: ["tiktok", "everyday", "easy"], description: "The effortless model-off-duty updo.", imageName: "claw-clip"),
        Hairstyle(name: "Half-Up Half-Down", category: .women, length: .long, texture: .wavy, tags: ["tiktok", "romantic", "trending"], description: "The viral half-up style. Effortlessly romantic and elegant.", imageName: "half-up-half-down"),
        Hairstyle(name: "Wet Look", category: .women, length: .long, texture: .straight, tags: ["identity", "glam", "bold", "editorial"], description: "High-fashion slicked-back wet effect. Bold runway energy.", imageName: "wet-look"),
        Hairstyle(name: "Wolf Cut", category: .women, length: .medium, texture: .wavy, tags: ["trendy", "tiktok", "viral", "edgy"], description: "The rebellious layered cut with shaggy, voluminous texture.", imageName: "wolf-cut"),
        Hairstyle(name: "Wavy Lob", category: .women, length: .medium, texture: .wavy, tags: ["trendy", "chic", "effortless"], description: "The perfect length with effortless beach waves.", imageName: "wavy-lob"),
        Hairstyle(name: "Defined Curls", category: .women, length: .long, texture: .curly, tags: ["trendy", "natural", "bouncy"], description: "Perfectly defined, bouncy curls with beautiful volume.", imageName: "defined-curls"),

        // Curtain Bangs moved to TikTok section
        Hairstyle(name: "Curtain Bangs", category: .women, length: .long, texture: .wavy, tags: ["tiktok", "bangs", "popular", "viral"], description: "See if face-framing bangs suit you without the cut.", imageName: "curtain-bangs"),
        Hairstyle(name: "The Italian Bob", category: .women, length: .short, texture: .wavy, tags: ["trendy", "chic", "transformation"], description: "The elegant Italian Bob with soft waves and effortless sophistication.", imageName: "italian-bob"),
        
        // MARK: - Safe / Everyday (Comfort Zone)
        Hairstyle(name: "Soft Waves", category: .women, length: .long, texture: .wavy, tags: ["safe", "natural", "classic"], description: "Perfect effortless waves for everyday.", imageName: "soft-waves"),
        Hairstyle(name: "Sleek Straight", category: .women, length: .long, texture: .straight, tags: ["safe", "classic", "clean"], description: "Timeless, smooth straight look.", imageName: "sleek-straight"),
        Hairstyle(name: "Beach Texture", category: .women, length: .medium, texture: .wavy, tags: ["safe", "casual", "summer"], description: "Effortless salt-spray texture.", imageName: "beach-waves"),
        Hairstyle(name: "Bouncy Blowout", category: .women, length: .long, texture: .wavy, tags: ["safe", "volume", "classic", "everyday"], description: "Salon-fresh bouncy volume. The ultimate confidence boost.", imageName: "bouncy-blowout"),
        
        // MARK: - More Styles
        Hairstyle(name: "Modern Shag", category: .women, length: .medium, texture: .wavy, tags: ["edgy", "texture"], description: "Textured layers with a rock-chic vibe.", imageName: "modern-shag"),
        Hairstyle(name: "Hush Cut", category: .women, length: .long, texture: .straight, tags: ["kstyle", "soft", "light"], description: "Soft, whisper-light layers.", imageName: "hush-cut"),

        Hairstyle(name: "High Ponytail", category: .women, length: .long, texture: .straight, tags: ["snatched", "party"], description: "Snatched high ponytail, Ariana style.", imageName: "high-ponytail"),
        Hairstyle(name: "Sleek Middle Part", category: .women, length: .long, texture: .straight, tags: ["clean", "fashion"], description: "Defined middle part, sharp and clean.", imageName: "sleek-middle-part"),
    ]
    
    static let men: [Hairstyle] = [
        // MARK: - Identity Shift (The "Dream Self") - Men
        Hairstyle(name: "Modern Slick Back", category: .men, length: .medium, texture: .straight, tags: ["identity", "iconic", "night", "popular", "trendy"], description: "Hair slicked back, clean effect.", imageName: "classic-slick-back"),
        
        // MARK: - TikTok / Viral (Social Proof) - Men
        Hairstyle(name: "Blowout Taper", category: .men, length: .medium, texture: .wavy, tags: ["tiktok", "trendy", "viral"], description: "Volume + taper, very TikTok/IG.", imageName: "blowout-taper"),
        Hairstyle(name: "Two-Block (K-Style)", category: .men, length: .medium, texture: .straight, tags: ["tiktok", "identity", "kstyle", "trendy", "popular"], description: "Short sides, longer top.", imageName: "two-block"),
        Hairstyle(name: "Curtains (Middle Part)", category: .men, length: .medium, texture: .wavy, tags: ["tiktok", "90s", "trendy", "popular"], description: "Middle part + curtain strands.", imageName: "curtains"),
        Hairstyle(name: "Textured Crop", category: .men, length: .short, texture: .wavy, tags: ["tiktok", "trendy", "easy", "popular"], description: "Short crop with texture.", imageName: "french-corp"),
        Hairstyle(name: "Natural Flow", category: .men, length: .medium, texture: .wavy, tags: ["tiktok", "trendy", "texture", "popular"], description: "Natural wavy flow.", imageName: "natural-flow"),
        
        // MARK: - Decision Anxiety (The "What if?") - Men
        Hairstyle(name: "Undercut", category: .men, length: .medium, texture: .straight, tags: ["decision", "iconic", "contrast", "trendy"], description: "Long top, very short sides.", imageName: "undercut"),
        Hairstyle(name: "Quiff", category: .men, length: .medium, texture: .straight, tags: ["decision", "volume", "classic", "popular"], description: "Volume up at the front.", imageName: "quiff"),
        Hairstyle(name: "Bro Flow", category: .men, length: .long, texture: .wavy, tags: ["decision", "safe", "effortless", "popular"], description: "Long natural, styled back.", imageName: "bro-flow"),
        
        // MARK: - Safe / Everyday (Comfort Zone) - Men
        Hairstyle(name: "Buzz Cut", category: .men, length: .buzz, texture: nil, tags: ["safe", "minimal", "classic", "popular"], description: "Very very short buzz, uniform.", imageName: "buzz-cut"),
        Hairstyle(name: "Low Fade", category: .men, length: .short, texture: nil, tags: ["safe", "classic", "clean", "popular", "trendy"], description: "Low fade, natural.", imageName: "low-fade"),
        Hairstyle(name: "Clean Cut", category: .men, length: .buzz, texture: nil, tags: ["safe", "low-maintenance", "classic", "popular"], description: "Ultra short, minimal, easy.", imageName: "clean-cut"),
        Hairstyle(name: "Skin Fade", category: .men, length: .short, texture: nil, tags: ["safe", "sharp", "barber", "trendy"], description: "Fade to skin, ultra clean.", imageName: "skin-fade"),

        
        // MARK: - More Styles - Men
        Hairstyle(name: "High & Tight", category: .men, length: .short, texture: .straight, tags: ["sharp", "clean"], description: "Very short sides, short top.", imageName: nil),
        Hairstyle(name: "Caesar Cut", category: .men, length: .short, texture: .straight, tags: ["classic"], description: "Short straight bangs, Caesar style.", imageName: nil),
        Hairstyle(name: "Ivy League", category: .men, length: .short, texture: .straight, tags: ["preppy", "timeless"], description: "Short chic, easy to style.", imageName: nil),
        Hairstyle(name: "Comb Over", category: .men, length: .medium, texture: .straight, tags: ["classic"], description: "Combed to the side, clean.", imageName: nil),
        Hairstyle(name: "Disconnected Undercut", category: .men, length: .medium, texture: .straight, tags: ["bold", "trendy"], description: "Marked contrast top/sides.", imageName: nil),
        Hairstyle(name: "Taper Fade", category: .men, length: .short, texture: nil, tags: ["timeless"], description: "Light fade on nape/temples.", imageName: nil),
        Hairstyle(name: "Modern Pompadour", category: .men, length: .medium, texture: .wavy, tags: ["identity", "modern", "barber", "trendy"], description: "More natural pompadour, fade.", imageName: "modern-mompadour"),
        Hairstyle(name: "Faux Hawk", category: .men, length: .medium, texture: .straight, tags: ["edgy"], description: "Light mohawk, wearable.", imageName: nil),
        Hairstyle(name: "Spiky Hair (Modern)", category: .men, length: .short, texture: .straight, tags: ["y2k", "trendy"], description: "Modern spikes, not cartoon.", imageName: nil),
        Hairstyle(name: "Comma Hair", category: .men, length: .medium, texture: .straight, tags: ["kstyle", "viral", "trendy"], description: "Comma-shaped strand on forehead.", imageName: nil),
        Hairstyle(name: "Mullet (Modern)", category: .men, length: .medium, texture: .wavy, tags: ["trendy", "edgy"], description: "Longer back, modern.", imageName: nil),
        Hairstyle(name: "Messy Fringe", category: .men, length: .medium, texture: .wavy, tags: ["casual", "trendy"], description: "Messy bangs, relaxed style.", imageName: nil),
        Hairstyle(name: "Surfer Hair", category: .men, length: .long, texture: .wavy, tags: ["beach", "casual"], description: "Wavy long, surfer vibe.", imageName: nil),
        Hairstyle(name: "Top Knot", category: .men, length: .long, texture: .straight, tags: ["clean"], description: "High bun, shorter sides.", imageName: nil),
        Hairstyle(name: "Shag (Men)", category: .men, length: .medium, texture: .wavy, tags: ["texture", "cool"], description: "Textured layers, effortless.", imageName: nil),
        Hairstyle(name: "Wolf Cut (Men)", category: .men, length: .medium, texture: .wavy, tags: ["trendy"], description: "Layers + texture, fashion vibe.", imageName: nil),
        Hairstyle(name: "Afro Fade", category: .men, length: .medium, texture: .coily, tags: ["iconic", "barber", "popular"], description: "Afro + clean fade.", imageName: "afro-fade"),
        Hairstyle(name: "High Top Fade", category: .men, length: .medium, texture: .coily, tags: ["iconic"], description: "Vertical volume, statement.", imageName: nil),
        Hairstyle(name: "Twists", category: .men, length: .medium, texture: .coily, tags: ["protective", "popular"], description: "Twists, clean and durable look.", imageName: nil),
        Hairstyle(name: "Braids (Men)", category: .men, length: .long, texture: .coily, tags: ["protective", "popular"], description: "Braids, various styles.", imageName: nil),
        Hairstyle(name: "Cornrows (Men)", category: .men, length: .medium, texture: .coily, tags: ["protective", "classic", "iconic"], description: "Flat braids, clean.", imageName: "cornrows-men"),
        Hairstyle(name: "Dreadlocks", category: .men, length: .long, texture: .coily, tags: ["iconic", "protective"], description: "Long locs, signature style.", imageName: "dreadlocks"),
        Hairstyle(name: "Starter Locs", category: .men, length: .short, texture: .coily, tags: ["protective"], description: "Beginning locs, short.", imageName: nil),
        Hairstyle(name: "Temple Fade", category: .men, length: .short, texture: nil, tags: ["barber", "clean"], description: "Fade on temples.", imageName: nil),
        Hairstyle(name: "Line-Up / Shape-Up", category: .men, length: .short, texture: nil, tags: ["sharp", "barber", "popular"], description: "Ultra clean contours.", imageName: "line-up"),
        Hairstyle(name: "Buzz + Beard (Style)", category: .men, length: .buzz, texture: nil, tags: ["popular", "masculine"], description: "Simple buzz, strong look with beard.", imageName: nil),
        Hairstyle(name: "Short Brush Up", category: .men, length: .short, texture: .straight, tags: ["easy", "clean"], description: "Top brushed upward.", imageName: nil),
    ]
}

// MARK: - Notification Names
extension Notification.Name {
    static let syncGenerationAfterPurchase = Notification.Name("syncGenerationAfterPurchase")
    static let authSuccess = Notification.Name("authSuccess")
}
