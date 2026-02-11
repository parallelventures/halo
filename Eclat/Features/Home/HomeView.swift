//
//  HomeView.swift
//  Eclat
//
//  v1.2 - Premium Home Screen Redesign
//

import SwiftUI
import PhotosUI
import Intercom

struct HomeView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var creditsService: CreditsService
    @ObservedObject private var generationService = GenerationService.shared
    
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showAccountSheet = false
    @State private var selectedGender: StyleGender = .women
    @State private var showOutOfLooksSheet = false
    @State private var showColorPicker = false
    @State private var pendingStyle: StylePreference?

    
    enum StyleGender: String, CaseIterable {
        case women = "Women"
        case men = "Men"
    }
    
    // Convert StyleGender to StyleCategory for filtering
    private var currentCategory: StyleCategory {
        selectedGender == .women ? .women : .men
    }
    
    // Get styles based on selected gender - ONLY with images
    private var trendingStyles: [StylePreference] {
        let styles = selectedGender == .women ? StylePreference.womenStyles : StylePreference.menStyles
        return styles.filter { $0.image != nil }
    }
    
    // All available styles for the grid - ONLY with images
    private var allStyles: [StylePreference] {
        let styles = selectedGender == .women ? StylePreference.womenStyles : StylePreference.menStyles
        return styles.filter { $0.image != nil }
    }
    
    // Section-specific styles (dynamic based on gender)
    private var tiktokStyles: [StylePreference] {
        StylePreference.tiktokStyles(for: currentCategory).filter { $0.image != nil }
    }
    
    private var identityStyles: [StylePreference] {
        StylePreference.identityShiftStyles(for: currentCategory).filter { $0.image != nil }
    }
    
    private var decisionStyles: [StylePreference] {
        StylePreference.decisionStyles(for: currentCategory).filter { $0.image != nil }
    }
    
    private var safeStyles: [StylePreference] {
        StylePreference.safeStyles(for: currentCategory).filter { $0.image != nil }
    }
    
    // New hairstyles section - explicitly show these 4 new styles
    private var newHairstyles: [StylePreference] {
        let newStyleNames = ["Wolf Cut", "Wavy Lob", "Defined Curls", "The Italian Bob"]
        // Use styles() without limit to find all new styles, not just the first 12
        let allStyles = StylePreference.styles(category: selectedGender == .women ? .women : .men)
        return allStyles.filter { newStyleNames.contains($0.name) && $0.image != nil }
    }
    
    var body: some View {
        ZStack {
            // Aurora background
            Color(hex: "0B0606")
            
            // Main content
            ZStack(alignment: .top) {
                // ScrollView (Behind header)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Spacer for header
                        Color.clear.frame(height: 70)
                        
                        // MARK: - Top Header (Personalized)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedGender == .women ? "NEW HAIRSTYLES" : "STYLES")
                                    .font(.custom("GTAlpinaTrial-CondensedThin", size: 24))
                                    .foregroundColor(.white)
                                
                                Text(selectedGender == .women ? "Just added to the collection" : "Curated for you")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // MARK: - 0. New Hairstyles Cards (Women only)
                        if !newHairstyles.isEmpty && selectedGender == .women {
                            newHairstylesCards
                        }
                        
                        // MARK: - 1. Trending (Dopamine)
                        trendingSection
                        
                        
                        // MARK: - 1.5 Color Styles (Retention) - Women only
                        if selectedGender == .women {
                            colorSection
                        }
                        
                        // MARK: - 2. Identity Shift (Desire)
                        identityShiftSection
                        
                        // MARK: - 3. Safe (Everyday)
                        safeSection
                        
                        // MARK: - 5. Real Users (Social Proof)
                        realUsersSection
                        
                        // MARK: - 6. Creator Mode Section (Hidden for now)
                        // creatorModeSection
                        
                        // Bottom padding for CTA
                        Color.clear.frame(height: 100)
                    }
                    .padding(.bottom, 20)
                }
                
                // MARK: - Variable Blur Layer (under header)
                VStack {
                    ZStack {
                        VariableBlurView(radius: 10, mask: .progressiveBlurMask)
                        
                        // Darken header area for legibility
                        LinearGradient(
                            colors: [.black.opacity(0.95), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .frame(height: 120)
                    .ignoresSafeArea(edges: .top)
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // MARK: - Sticky Header
                headerView
            }
            
            // MARK: - Bottom CTA
            bottomCTA
        }
        .task {
            await generationService.fetchGenerations()
        }
        .onAppear {
            TikTokService.shared.trackHomeViewed()
            
            // Sync gender from Onboarding
            if let category = OnboardingDataService.shared.localData.styleCategory {
                 if category.lowercased() == "men" {
                     selectedGender = .men
                 } else {
                     selectedGender = .women
                 }
            }
            
            // Login to Intercom for identification (but launcher stays hidden - we use custom button in settings)
            Intercom.loginUnidentifiedUser()
            
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheetOpal()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showOutOfLooksSheet) {
            OutOfLooksSheet()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .presentationBackground(.clear)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task { await loadPhoto(newValue) }
        }

        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheet(
                selectedColor: $appState.selectedColor,
                styleName: pendingStyle?.name ?? appState.selectedHairstyle?.name ?? "Style",
                onSelect: { color in
                    appState.selectedColor = color
                    proceedWithStyle()
                },
                onSkip: {
                    appState.selectedColor = nil
                    proceedWithStyle()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Eclat")
                .font(.eclat.displaySmall)
                .foregroundColor(.white)
                .fixedSize()
                .padding(.vertical, 4)
                .onTapGesture(count: 3) { // Secret triple tap access
                    // Dev access removed
                }
            

            Spacer()
            
            // Looks balance indicator
            Button {
                HapticManager.shared.buttonPress()
                if subscriptionManager.isSubscribed {
                    // Subscribed users go to manage/upgrade
                    appState.navigateTo(.creditsPaywall)
                } else {
                    appState.showPaywall()
                }
            } label: {
                HStack(spacing: 6) {
                    switch subscriptionManager.currentTier {
                    case .atelier:
                        Text("✨ Unlimited")
                            .font(.system(size: 14, weight: .semibold))
                    case .creator:
                        // Total usable looks = weekly remaining + credit packs
                        let totalLooks = subscriptionManager.weeklyLooksRemaining + creditsService.balance
                        Text("✨ \(totalLooks) Looks")
                            .font(.system(size: 14, weight: .semibold))
                    case .free:
                        if creditsService.balance > 0 {
                            Text("💎 \(creditsService.balance) Looks")
                                .font(.system(size: 14, weight: .semibold))
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Upgrade")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(height: 48)
                .padding(.horizontal, 16)
            }
            .glassChipStyle()
            
            // History
            Button {
                HapticManager.shared.buttonPress()
                appState.showHistorySheet = true
            } label: {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 48, height: 48)
            }
            .glassCircleStyle()
            
            // Account button
            Button {
                HapticManager.shared.buttonPress()
                showAccountSheet = true
            } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 48, height: 48)
            }
            .glassCircleStyle()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.5), location: 0),
                    .init(color: Color.black.opacity(0.3), location: 0.5),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - Welcome Hero (REMOVED - silence visuel = premium)
    // Le copy générique "Find Your Perfect Look" a été supprimé
    // Les apps à 500k-1M$/mo retirent le copy explicatif et laissent l'utilisateur projeter
    private var welcomeHero: some View {
        EmptyView()
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "GET STARTED")
            
            HStack(spacing: 12) {
                // Take Selfie
                Button {
                    HapticManager.shared.buttonPress()
                    // Non-subscribers must pay first (0 free generations)
                    if !subscriptionManager.hasLooks {
                        showOutOfLooksSheet = true
                    } else {
                        appState.showCameraSheet = true
                    }
                } label: {
                    quickActionCard(
                        image: "Selfie",
                        title: "Take Selfie",
                        icon: "camera.fill"
                    )
                }
                
                // From Gallery
                Button {
                    HapticManager.shared.buttonPress()
                    // Non-subscribers must pay first (0 free generations)
                    if !subscriptionManager.hasLooks {
                        showOutOfLooksSheet = true
                    } else {
                        showingPhotoPicker = true
                    }
                } label: {
                    quickActionCard(
                        image: "Selfie1",
                        title: "From Gallery",
                        icon: "photo.fill"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func quickActionCard(image: String, title: String, icon: String) -> some View {
        ZStack(alignment: .bottom) {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Label
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassBubbleStyle()
            .padding(.bottom, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - New Hairstyles Cards (header is now in the main top section)
    private var newHairstylesCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(newHairstyles) { style in
                    TrendingStyleCardV2(style: style) {
                        selectStyle(style)
                    }
                    .styleCardScrollTransition()
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
    }
    
    // MARK: - Trending Section
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "TRENDING NOW", subtitle: "What's hot on TikTok?")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tiktokStyles) { style in
                        TrendingStyleCardV2(style: style) {
                           selectStyle(style)
                        }
                        .styleCardScrollTransition()
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    // MARK: - Color Styles Section (NEW)
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("COLOR STYLES")
                            .font(.custom("GTAlpinaTrial-CondensedThin", size: 24))
                            .foregroundColor(.white)
                        
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    
                    Text("Cut then Color. Refine the tone.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Safe colors
                    ForEach(HairColorData.colors(for: .safe)) { color in
                        ColorStyleCard(color: color) {
                            selectColor(color)
                        }
                        .styleCardScrollTransition()
                    }
                    
                    // Premium colors
                    ForEach(HairColorData.colors(for: .premium)) { color in
                        ColorStyleCard(color: color, badge: "✨ PREMIUM") {
                            selectColor(color)
                        }
                        .styleCardScrollTransition()
                    }
                    
                    // Bold colors
                    ForEach(HairColorData.colors(for: .bold)) { color in
                        ColorStyleCard(color: color, badge: "NEW") {
                            selectColor(color)
                        }
                        .styleCardScrollTransition()
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    // Helper for color selection
    private func selectColor(_ color: HairColor) {
        HapticManager.shared.buttonPress()
        appState.selectedColor = nil // Reset first
        
        // We need a base hairstyle for color - default to simple straight or user's last used
        if appState.selectedHairstyle == nil {
            // Default based on gender
            let defaultStyle = selectedGender == .women ? StylePreference.womenStyles.first : StylePreference.menStyles.first
            if let defaultStyle = defaultStyle?.hairstyle {
                appState.selectedHairstyle = defaultStyle
            }
        }
        
        appState.selectedColor = color
        
        if !subscriptionManager.hasLooks {
            showOutOfLooksSheet = true
        } else {
            appState.showCameraSheet = true
        }
    }

    // MARK: - Identity Shift Section
    private var identityShiftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "SHIFT YOUR IDENTITY", subtitle: "Who do you want to be today?")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(identityStyles) { style in
                        TrendingStyleCardV2(style: style) {
                            selectStyle(style)
                        }
                        .styleCardScrollTransition()
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    // MARK: - Decision Section
    private var decisionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "THE \"SHOULD I?\" TEST", subtitle: "Try before you commit.")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(decisionStyles) { style in
                        TrendingStyleCardV2(style: style) {
                            selectStyle(style)
                        }
                        .styleCardScrollTransition()
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    // MARK: - Safe Section
    private var safeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "TIMELESS", subtitle: "Effortless looks for everyday.")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(safeStyles) { style in
                        TrendingStyleCardV2(style: style) {
                            selectStyle(style)
                        }
                        .styleCardScrollTransition()
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    // MARK: - Real Users Section (Silent Luxury)
    private var realUsersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Poetic, silent title
            Text("Seen in the wild")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 22) // Slightly indented
                .textCase(.uppercase)
                .tracking(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Use a subset of styles to simulate users
                    ForEach(Array(allStyles.dropFirst(4).prefix(6))) { style in
                         RealUserCard(style: style) {
                             selectStyle(style)
                         }
                         .scrollTransition { content, phase in
                             content
                                 .scaleEffect(phase.isIdentity ? 1.0 : 0.94)
                                 .opacity(phase.isIdentity ? 1.0 : 0.6) // More dramatic fade for focus
                                 .blur(radius: phase.isIdentity ? 0 : 1) // Depth of field effect
                         }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    // Helper used by all cards
    private func selectStyle(_ style: StylePreference) {
        HapticManager.shared.buttonPress()
        if let hairstyle = style.hairstyle {
            appState.selectedHairstyle = hairstyle
        }
        if !subscriptionManager.hasLooks {
            showOutOfLooksSheet = true
        } else {
            // Store style
            pendingStyle = style
            appState.selectedColor = nil // Reset any previous color
            
            // 🎨 Color picker only for Women (colors are women-only)
            if selectedGender == .women {
                showColorPicker = true
            } else {
                // Men: skip color picker, go directly to camera
                appState.showCameraSheet = true
            }
        }
    }
    
    // Proceed after color selection (or skip)
    private func proceedWithStyle() {
        showColorPicker = false
        pendingStyle = nil
        appState.showCameraSheet = true
    }
    
    // MARK: - Creator Mode Section
    private var creatorModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if subscriptionManager.isSubscribed {
                // Subscriber: Just show header with active badge
                subscriberCreatorHeader
            } else {
                // Non-subscriber: Show full section with CTA
                nonSubscriberCreatorSection
            }
        }
    }
    
    // MARK: - Subscriber Creator Header
    private var subscriberCreatorHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("CREATOR MODE")
                        .font(.custom("GTAlpinaTrial-CondensedThin", size: 24))
                        .foregroundColor(.white)
                    
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
                
                Text("Unlimited looks, studio-grade quality")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Non-Subscriber Creator Section
    private var nonSubscriberCreatorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Clean header with title and subtitle only
            VStack(alignment: .center, spacing: 8) {
                Text("Creator Mode")
                    .font(.custom("GTAlpinaTrial-CondensedThin", size: 34))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Unlimited looks, studio-grade quality")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Fanned cards visual - clean, centered
            creatorModeFannedCards
                .frame(height: 280)
                .padding(.horizontal, 20)
            
            // Single clean subscription card
            Button {
                HapticManager.shared.buttonPress()
                appState.showPaywall()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Creator Mode")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Unlimited looks")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text("$9.99/week")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PremiumTouchButtonStyle())
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Creator Mode Card (Removed - using inline button above)
    private var creatorModeCard: some View {
        EmptyView()
    }
    
    // MARK: - Fanned Cards Visual (Compact for Card)
    private var creatorModeFannedCards: some View {
        let displayStyles = Array(allStyles.prefix(5))
        let count = min(5, displayStyles.count)
        let center = 2
        
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let offset = index - center
                if let imageName = displayStyles[index].image {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .rotationEffect(.degrees(Double(offset) * 6))
                        .offset(x: CGFloat(offset) * 18, y: CGFloat(abs(offset)) * 6)
                        .scaleEffect(1.0 - (CGFloat(abs(offset)) * 0.05))
                        .zIndex(Double(count - abs(offset)))
                }
            }
        }
    }
    
    // MARK: - Social Proof Banner
    private var socialProofBanner: some View {
        HStack(spacing: 16) {
            // Stats
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    Text("50,000+")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("looks created")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Rating
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
                Text("4.9 on App Store")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .glassCardStyle(cornerRadius: 20)
    }
    
    // MARK: - Upgrade Card
    private var upgradeCard: some View {
        Button {
            HapticManager.shared.buttonPress()
            appState.showPaywall()
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ProBadge(size: 16, color: .white)
                        Text("Unlock Creator Mode")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text("20 looks/week • Studio-Grade Quality • No watermarks")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.5), Color.pink.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .glassCardStyle(cornerRadius: 20)
        }
    }
    
    // MARK: - Bottom CTA (Aurora Breathing)
    private var bottomCTA: some View {
        VStack {
            Spacer()
            
            let hasAccess = subscriptionManager.hasLooks || creditsService.balance > 0
            
            // Dynamic emotional CTA based on tier
            let ctaTitle: String = {
                switch subscriptionManager.currentTier {
                case .atelier:
                    return "See this version of you"  // Emotional
                case .creator:
                    let totalLooks = subscriptionManager.weeklyLooksRemaining + creditsService.balance
                    if totalLooks <= 3 {
                        return "\(totalLooks) looks left"
                    }
                    return "See this version of you"
                case .free:
                    if creditsService.balance > 0 {
                        return "See this version of you"
                    }
                    return "Get Looks"
                }
            }()
            
            VStack(spacing: 8) {
                GlassCapsuleButton(
                    title: ctaTitle,
                    systemImage: hasAccess ? "" : "plus.circle.fill",
                    shimmer: hasAccess
                ) {
                    HapticManager.shared.buttonPress()
                    if !hasAccess {
                        showOutOfLooksSheet = true
                    } else {
                        appState.showCameraSheet = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    // MARK: - Section Header Helper (Updated for subtitle)
    private func sectionHeader(title: String, subtitle: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("GTAlpinaTrial-CondensedThin", size: 24))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Load Photo
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            appState.setCapturedImage(image)
        }
    }
}



// MARK: - Trending Style Card V2 (with real images)
struct TrendingStyleCardV2: View {
    let style: StylePreference
    var badge: String? = nil
    let action: () -> Void
    
    // Breathing animation state
    @State private var isBreathing = false
    
    // Tooltip state for badge
    @State private var showBadgeTooltip = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main card button
            Button(action: action) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .bottom) {
                        if let imageName = style.image {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 260)
                                .clipped()
                        } else {
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay(
                                Image(systemName: style.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.6))
                            )
                        }
                        
                        // Gradient overlay
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        
                        // Style name
                        Text(style.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 16)
                    }
                    .frame(width: 200, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // MARK: - Badge Overlay (OUTSIDE Button - tappable)
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassBadgeStyle()
                    .scaleEffect(showBadgeTooltip ? 1.08 : 1.0)
                    .padding(10)
                    .contentShape(Rectangle())  // Expand tap area
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded { _ in
                                HapticManager.light()
                                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.7, blendDuration: 0.15)) {
                                    showBadgeTooltip = true
                                }
                                // Auto-hide after 2.5s
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
                                        showBadgeTooltip = false
                                    }
                                }
                            }
                    )
            }
            
            // MARK: - Badge Tooltip (Curated looks explanation)
            if showBadgeTooltip && badge != nil {
                Text("Curated looks users love the most")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    )
                    .scaleEffect(showBadgeTooltip ? 1.0 : 0.85)
                    .offset(x: 12, y: 48)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(100)
            }
        }
        // Passive breathing - quasi invisible (0.98 ↔ 1.0)
        .opacity(isBreathing ? 1.0 : 0.98)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 4)
                .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
    }
}

// MARK: - Style Grid Card V2 (with real images)
struct StyleGridCardV2: View {
    let style: StylePreference
    let action: () -> Void
    
    // Breathing animation state
    @State private var isBreathing = false
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                // Real image
                if let imageName = style.image {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: style.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.6))
                    )
                }
                
                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                // Style name
                Text(style.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        // Passive breathing - quasi invisible (0.98 ↔ 1.0)
        .opacity(isBreathing ? 1.0 : 0.98)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 4)
                .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
    }
}

// MARK: - Real User Card (Silent / Pure)
struct RealUserCard: View {
    let style: StylePreference
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if let imageName = style.image {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 200) // Pure ratio
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    // No text, no gradient, no badge. Pure image.
            } else {
                 Color.white.opacity(0.05)
                    .frame(width: 150, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Glass Style Extensions
extension View {
    @ViewBuilder
    func glassBadgeStyle() -> some View {
        self
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: Capsule())
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    func glassCTAStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    func glassCircleStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            self
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    func glassChipStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    func glassBubbleStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular, in: Capsule())
        } else {
            self
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    func glassCardStyle(cornerRadius: CGFloat = 24) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager())
}

// MARK: - Account Sheet
struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var creditsService: CreditsService
    @State private var showDeleteAlert = false
    @State private var showLogoutAlert = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "0B0606").ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // MARK: - Profile Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 90, height: 90)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            VStack(spacing: 6) {
                                Text(subscriptionManager.currentTier.displayName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                let looksText: String = {
                                    switch subscriptionManager.currentTier {
                                    case .atelier: return "Unlimited Looks"
                                    case .creator:
                                        let total = subscriptionManager.weeklyLooksRemaining + creditsService.balance
                                        return "\(total) Looks"
                                    case .free:
                                        return creditsService.balance > 0
                                            ? "\(creditsService.balance) Looks"
                                            : "0 Looks"
                                    }
                                }()
                                Text(looksText)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            // Edit Profile Button
                            Button {
                                showEditProfile = true
                            } label: {
                                Text("Edit Profile")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(height: 36)
                                    .padding(.horizontal, 24)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.top, 20)
                        
                        // MARK: - Menu Sections
                        VStack(spacing: 20) {
                            
                            // 1. Subscription
                            if !subscriptionManager.isSubscribed {
                                Button {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        appState.showPaywall()
                                    }
                                } label: {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 36, height: 36)
                                            
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 16))
                                                .foregroundColor(.black)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Upgrade to Creator")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text("20 looks/week")
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                            
                            // 2. Settings Group
                            VStack(spacing: 1) {
                                AccountRow(icon: "gearshape", title: "Manage Subscription") {
                                    openSubscriptionSettings()
                                }
                                
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 56)
                                
                                AccountRow(icon: "arrow.clockwise", title: "Restore Purchases") {
                                    Task { await subscriptionManager.restorePurchases() }
                                }
                            }
                            .applyAccountGlassEffect()
                            
                            // 3. Support Group
                            VStack(spacing: 1) {
                                AccountRow(icon: "star", title: "Rate Eclat") {
                                    requestReview()
                                }
                                
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 56)
                                
                                AccountRow(icon: "envelope", title: "Send Feedback") {
                                    sendFeedback()
                                }
                                
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 56)
                                
                                AccountRow(icon: "questionmark.circle", title: "Help & Support") {
                                    openURL("https://parallelventures.eu/support/")
                                }
                            }
                            .applyAccountGlassEffect()
                            
                            // 4. Legal Group
                            VStack(spacing: 1) {
                                AccountRow(icon: "hand.raised", title: "Privacy Policy") {
                                    openURL("https://parallelventures.eu/privacy-policy/")
                                }
                                
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 56)
                                
                                AccountRow(icon: "doc.text", title: "Terms of Service") {
                                    openURL("https://parallelventures.eu/terms-of-use/")
                                }
                            }
                            .applyAccountGlassEffect()
                            
                            // 5. Danger Zone
                            VStack(spacing: 1) {
                                AccountRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out", isDestructive: false) {
                                    showLogoutAlert = true
                                }
                                
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 56)
                                
                                AccountRow(icon: "trash", title: "Delete Account", isDestructive: true) {
                                    showDeleteAlert = true
                                }
                            }
                            .applyAccountGlassEffect()
                        }
                        
                        // Version
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("Version \(version)")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)

            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    AuthService.shared.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await AuthService.shared.deleteAccount()
                        dismiss()
                    }
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func openSubscriptionSettings() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func requestReview() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendFeedback() {
        if let url = URL(string: "https://parallelventures.eu/support/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Modern Account Row
struct AccountRow: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isDestructive ? Color.red.opacity(0.1) : Color.white.opacity(0.05))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(isDestructive ? .red : .white.opacity(0.9))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? .red : .white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Notification for showing paywall
extension Notification.Name {
    static let showPaywall = Notification.Name("showPaywall")
}

// MARK: - Style Card Scroll Transition Extension
extension View {
    func styleCardScrollTransition() -> some View {
        if #available(iOS 17.0, *) {
            return self.scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .blur(radius: phase.isIdentity ? 0 : 1)       // Very subtle blur
                    .opacity(phase.isIdentity ? 1 : 0.9)          // Very subtle fade
                    .scaleEffect(phase.isIdentity ? 1 : 0.95)     // Minimal shrink
            }
        } else {
            return self
        }
    }
}

// MARK: - Color Style Card
struct ColorStyleCard: View {
    let color: HairColor
    var badge: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                // Image
                Image(color.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 180)
                    .clipped()
                
                // Content Gradient
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(color.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(color.category.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                
                // Badge (Top Right)
                if let badge = badge {
                    VStack {
                        HStack {
                            Spacer()
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .frame(width: 140, height: 180)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Color Picker Sheet (Clean & Minimalist)
struct ColorPickerSheet: View {
    @Binding var selectedColor: HairColor?
    let styleName: String
    let onSelect: (HairColor) -> Void
    let onSkip: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            VStack(spacing: 24) {
                // Title
                Text("Choose a color")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // All colors on one horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(HairColorData.allColors) { color in
                            ColorPickerCard(
                                color: color,
                                isSelected: selectedColor?.id == color.id
                            ) {
                                HapticManager.shared.buttonPress()
                                selectedColor = color
                                
                                // Auto-proceed after short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onSelect(color)
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 20)
                }
                .scrollTargetBehavior(.viewAligned)
                
                Spacer()
            }
            
            // Keep Natural Button (Bottom, White Capsule)
            VStack(spacing: 0) {
                // Gradient fade
                LinearGradient(
                    colors: [Color(hex: "0B0606").opacity(0), Color(hex: "0B0606")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                
                // Button container
                Button {
                    HapticManager.shared.buttonPress()
                    onSkip()
                } label: {
                    Text("Keep my natural color")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .background(Color(hex: "0B0606"))
            }
        }
        .background(Color(hex: "0B0606"))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Color Picker Card
struct ColorPickerCard: View {
    let color: HairColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                // Image
                Image(color.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 220)
                    .clipped()
                
                // Gradient
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                // Name
                Text(color.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                
                // Selection indicator
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.white)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                )
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }
            .frame(width: 160, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? Color.white : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
