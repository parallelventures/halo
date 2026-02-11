//
//  OnboardingView.swift
//  Eclat
//
//  Complete onboarding experience with style selection
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn
import StoreKit

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case styleFit = 0      // Men/Women selection
    case intention = 1     // Style preference
}

// MARK: - Style Category
enum StyleCategory: String, CaseIterable {
    case men = "Men"
    case women = "Women"
}

// MARK: - Style Preference (Bridge to HairstyleData)
struct StylePreference: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let image: String? // Optional image name
    let hairstyle: Hairstyle? // Reference to full hairstyle data
    
    init(name: String, icon: String, image: String?, hairstyle: Hairstyle? = nil) {
        self.name = name
        self.icon = icon
        self.image = image
        self.hairstyle = hairstyle
    }
    
    // Convert from Hairstyle
    init(from hairstyle: Hairstyle) {
        self.name = hairstyle.name
        self.icon = Self.iconFor(hairstyle: hairstyle)
        self.image = hairstyle.imageName
        self.hairstyle = hairstyle
    }
    
    private static func iconFor(hairstyle: Hairstyle) -> String {
        switch hairstyle.length {
        case .buzz: return "scissors"
        case .short: return "square.split.diagonal"
        case .medium: return "wind"
        case .long: return "arrow.down"
        }
    }
}

extension StylePreference {
    // Generic fetch helper
    static func styles(category: StyleCategory = .women, tag: String? = nil, limit: Int? = nil) -> [StylePreference] {
        let gender: GenderCategory = category == .women ? .women : .men
        var styles = HairstyleData.styles(for: gender)
        
        if let tag = tag {
            styles = styles.filter { $0.tags.contains(tag) }
        }
        
        if let limit = limit {
            return Array(styles.prefix(limit)).map { StylePreference(from: $0) }
        }
        return styles.map { StylePreference(from: $0) }
    }
    
    // Default Featured (Mix) - Keep reasonable for swipe UX
    static var menStyles: [StylePreference] {
        styles(category: .men, limit: 10)
    }
    
    static var womenStyles: [StylePreference] {
        styles(category: .women, limit: 12) // Reduced from 40 for better swipe UX
    }
    
    // Psychology Lists (High Conversion) - Default to women
    static var identityShiftStyles: [StylePreference] {
        styles(category: .women, tag: "identity")
    }
    
    static var tiktokStyles: [StylePreference] {
        styles(category: .women, tag: "tiktok")
    }
    
    static var decisionStyles: [StylePreference] {
        styles(category: .women, tag: "decision")
    }
    
    static var safeStyles: [StylePreference] {
        styles(category: .women, tag: "safe")
    }
    
    // Dynamic versions for gender toggle
    static func tiktokStyles(for category: StyleCategory) -> [StylePreference] {
        styles(category: category, tag: "tiktok")
    }
    
    static func identityShiftStyles(for category: StyleCategory) -> [StylePreference] {
        styles(category: category, tag: "identity")
    }
    
    static func decisionStyles(for category: StyleCategory) -> [StylePreference] {
        styles(category: category, tag: "decision")
    }
    
    static func safeStyles(for category: StyleCategory) -> [StylePreference] {
        styles(category: category, tag: "safe")
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var authService = AuthService.shared
    
    @State private var currentStep: OnboardingStep = .styleFit
    @State private var selectedCategory: StyleCategory?
    @State private var selectedStyle: StylePreference?
    @State private var showCamera = false
    
    // Swipe Logic State
    @State private var currentCardIndex = 0
    @State private var likedStyles: [StylePreference] = []
    @State private var cardAppeared: [Int: Bool] = [:]
    
    // Onboarding Fake Processing State (for review prompt flow)
    @State private var showOnboardingProcessing = false
    
    var body: some View {
        ZStack {
            // Aurora background
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            // Content based on step
            switch currentStep {
            case .styleFit:
                styleFitView
            case .intention:
                intentionView
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showOnboardingProcessing) {
            OnboardingProcessingView()
                .environmentObject(appState)
                .environmentObject(SubscriptionManager.shared)
        }
        .onChange(of: appState.capturedImage) { _, newImage in
            if newImage != nil && showCamera {
                showCamera = false
                // 🎯 ONBOARDING FLOW: Show fake processing with review prompt
                // This triggers the review ask before showing paywall
                // After paywall purchase/dismiss, user will be directed to real processing
                showOnboardingProcessing = true
            }
        }
        .onAppear {
            // Restore state if returning
            let savedStyles = OnboardingDataService.shared.getLikedStyles()
            if !savedStyles.isEmpty {
                if let categoryString = OnboardingDataService.shared.localData.styleCategory {
                    selectedCategory = StyleCategory(rawValue: categoryString.capitalized)
                }
                currentStep = .intention
            }
        }
    }
    
    // MARK: - VIEW 1: Style Fit
    private var styleFitView: some View {
        VStack(spacing: 0) {
            Text("Choose your look")
                .font(.eclat.displayLarge)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 80)
                .padding(.bottom, 40)
            
            Spacer()
            
            VStack(spacing: 12) {
                StyleFitCard(
                    title: "Men",
                    imageName: "men",
                    isSelected: selectedCategory == .men
                ) {
                    HapticManager.shared.buttonPress()
                    withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
                        selectedCategory = .men
                    }
                }
                
                StyleFitCard(
                    title: "Women",
                    imageName: "women",
                    isSelected: selectedCategory == .women
                ) {
                    HapticManager.shared.buttonPress()
                    withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
                        selectedCategory = .women
                    }
                }
            }
            .padding(.horizontal, 40)
            
            if selectedCategory != nil {
                Button {
                    HapticManager.shared.buttonPress()
                    saveCategorySelection()
                    withAnimation(.eclatSmooth) {
                        currentStep = .intention
                    }
                } label: {
                    if #available(iOS 26.0, *) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .contentShape(Capsule())
                            .glassEffect(.regular.tint(.white.opacity(0.9)), in: .capsule)
                    } else {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Capsule().fill(Color.white.opacity(0.85)))
                            .contentShape(Capsule())
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Spacer()
        }
    }
    
    // MARK: - VIEW 2: Intention (Swipe Cards)
    private var intentionView: some View {
        let styles = selectedCategory == .women ? StylePreference.womenStyles : StylePreference.menStyles
        let hasStoredStyles = !OnboardingDataService.shared.getLikedStyles().isEmpty
        let isFinished = currentCardIndex >= styles.count || hasStoredStyles
        
        return VStack(spacing: 0) {
            if isFinished {
                // Re-entry View (Waiting Room)
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Style Stack Visualization
                    ZStack {
                        let displayStyles = likedStyles.isEmpty ? Array(styles.prefix(3)) : likedStyles
                        let count = min(3, displayStyles.count)
                        
                        ForEach(0..<count, id: \.self) { index in
                            let style = displayStyles[index]
                            VStack {
                                if let imageName = style.image {
                                    Image(imageName).resizable().scaledToFill()
                                } else {
                                    Color.gray.opacity(0.3)
                                        .overlay(Image(systemName: style.icon).font(.system(size: 50)).foregroundColor(.white))
                                }
                            }
                            .frame(width: 220, height: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                            .rotationEffect(.degrees(Double(index - 1) * 6))
                            .offset(x: CGFloat(index - 1) * 30, y: CGFloat(abs(index - 1)) * 10)
                            .scaleEffect(cardAppeared[index] ?? false ? 1.0 - (CGFloat(abs(index - 1)) * 0.05) : 0.3)
                            .opacity(cardAppeared[index] ?? false ? 1.0 : 0.0)
                            .zIndex(Double(count - index))
                            .onAppear {
                                let delay = Double(index) * 0.15
                                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.15).delay(delay)) {
                                    cardAppeared[index] = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.35) {
                                    HapticManager.light()
                                }
                            }
                        }
                    }
                    .frame(height: 350)
                    .padding(.bottom, 20)
                        
                    VStack(spacing: 8) {
                        Text("Styles Ready")
                            .font(.eclat.displayMedium)
                            .foregroundColor(.white)
                        Text("Your selection is saved.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    Button {
                        HapticManager.shared.buttonPress()
                        showCamera = true
                    } label: {
                        Text("Open Camera")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white, in: Capsule())
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
                .transition(.opacity)
            } else {
                // Normal Swipe Flow
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("Swipe the styles you like")
                            .font(.eclat.displayLarge)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("This helps personalize your preview.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 24)
                    
                    Spacer()
                    
                    // Swipe Card Stack
                    ZStack {
                        ForEach(Array(styles.enumerated().reversed()), id: \.element.id) { index, style in
                            if index >= currentCardIndex {
                                SwipeCard(
                                    style: style,
                                    isTopCard: index == currentCardIndex,
                                    onSwipe: { direction in
                                        handleSwipe(direction: direction, style: style)
                                    }
                                )
                                .offset(y: CGFloat(index - currentCardIndex) * 4)
                                .scaleEffect(index == currentCardIndex ? 1.0 : 0.95)
                                .opacity(1.0)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 40) {
                        Button {
                            HapticManager.light()
                            skipCurrentCard()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 72, height: 72)
                                .glassButtonCircle(color: .white.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button {
                            HapticManager.shared.buttonPress()
                            likeCurrentCard()
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 72, height: 72)
                                .glassButtonCircle(color: Color(red: 1.0, green: 0.2, blue: 0.4).opacity(0.25))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
    }
    
    private func handleSwipe(direction: SwipeDirection, style: StylePreference) {
        if direction == .right {
            likedStyles.append(style)
            Task { await OnboardingDataService.shared.trackEvent(OnboardingDataService.EventName.styleSwipedLike, data: ["style": style.name]) }
        } else {
            Task { await OnboardingDataService.shared.trackEvent(OnboardingDataService.EventName.styleSwipedSkip, data: ["style": style.name]) }
        }
        
        currentCardIndex += 1
        
        let styles = selectedCategory == .women ? StylePreference.womenStyles : StylePreference.menStyles
        if currentCardIndex >= styles.count {
            OnboardingDataService.shared.saveLikedStyles(likedStyles)
            if let firstLiked = likedStyles.first?.hairstyle {
                appState.selectedHairstyle = firstLiked
            } else if let fallback = styles.first?.hairstyle {
                appState.selectedHairstyle = fallback
            }
            Task { await OnboardingDataService.shared.trackEvent(OnboardingDataService.EventName.allStylesSwiped) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showCamera = true }
        }
    }
    
    private func skipCurrentCard() {
        let styles = selectedCategory == .women ? StylePreference.womenStyles : StylePreference.menStyles
        guard currentCardIndex < styles.count else { return }
        handleSwipe(direction: .left, style: styles[currentCardIndex])
    }
    
    private func likeCurrentCard() {
        let styles = selectedCategory == .women ? StylePreference.womenStyles : StylePreference.menStyles
        guard currentCardIndex < styles.count else { return }
        handleSwipe(direction: .right, style: styles[currentCardIndex])
    }
    
    private func saveCategorySelection() {
        guard let category = selectedCategory else { return }
        OnboardingDataService.shared.saveStyleCategory(category)
        Task { await OnboardingDataService.shared.trackEvent(OnboardingDataService.EventName.styleCategorySelected, data: ["category": category.rawValue]) }
    }
}

// MARK: - Style Fit Card
struct StyleFitCard: View {
    let title: String
    let imageName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4/5, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(4/5, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15), value: isSelected)
    }
}

// MARK: - Style Card
struct StyleCard: View {
    let style: StylePreference
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: style.icon).font(.system(size: 28)).foregroundColor(isSelected ? .black : .white)
                Text(style.name).font(.system(size: 14, weight: .medium)).foregroundColor(isSelected ? .black : .white).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).frame(height: 100)
            .background(RoundedRectangle(cornerRadius: 16).fill(isSelected ? Color.white : Color.white.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1))
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15), value: isSelected)
    }
}

// MARK: - Swipe Direction
enum SwipeDirection {
    case left
    case right
}

// MARK: - Swipe Card
struct SwipeCard: View {
    let style: StylePreference
    let isTopCard: Bool
    let onSwipe: (SwipeDirection) -> Void
    
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let imageName = style.image {
                GeometryReader { geometry in
                    Color(hex: "1C1C1E")
                        .overlay(Image(imageName).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped())
                }
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                LinearGradient(colors: [.clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Color.white.opacity(0.1))
                    .overlay(VStack(spacing: 16) { Image(systemName: style.icon).font(.system(size: 60, weight: .light)).foregroundColor(.white.opacity(0.8)) })
            }
            
            RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            Text(style.name).font(.system(size: 28, weight: .bold)).foregroundColor(.white).shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2).padding(.bottom, 32)
            
            if isDragging {
                if offset.width > 20 {
                    VStack { Text("LIKE").font(.system(size: 32, weight: .black)).foregroundColor(.green).padding(12).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.green, lineWidth: 4)).rotationEffect(.degrees(-15)) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(32).opacity(min(offset.width / swipeThreshold, 1.0))
                }
                if offset.width < -20 {
                    VStack { Text("NOPE").font(.system(size: 32, weight: .black)).foregroundColor(.red).padding(12).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red, lineWidth: 4)).rotationEffect(.degrees(15)) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(32).opacity(min(-offset.width / swipeThreshold, 1.0))
                }
            }
        }
        .aspectRatio(9/16, contentMode: .fit)
        .offset(x: offset.width, y: offset.height * 0.3)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    guard isTopCard else { return }
                    isDragging = true
                    offset = gesture.translation
                }
                .onEnded { gesture in
                    guard isTopCard else { return }
                    isDragging = false
                    if gesture.translation.width > swipeThreshold {
                         withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) { offset = CGSize(width: 500, height: 0) }
                         HapticManager.shared.buttonPress()
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onSwipe(.right) }
                    } else if gesture.translation.width < -swipeThreshold {
                         withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) { offset = CGSize(width: -500, height: 0) }
                         HapticManager.light()
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onSwipe(.left) }
                    } else {
                         withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) { offset = .zero }
                    }
                }
        )
    }
}

// MARK: - Glass Button Circle Extension
extension View {
    @ViewBuilder
    func glassButtonCircle(color: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.background(Circle().fill(color)).glassEffect(.regular.interactive(), in: Circle()).contentShape(Circle())
        } else {
            self.background(Circle().fill(color)).overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)).contentShape(Circle())
        }
    }
}
