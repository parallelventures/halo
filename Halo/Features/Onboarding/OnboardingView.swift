//
//  OnboardingView.swift
//  Halo
//
//  Premium onboarding flow with conversion-optimized steps
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn
import StoreKit

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case styleFit = 0      // Men/Women selection
    case intention = 1     // Style preference
    // case selfie removed
    case loading = 3       // Processing
    case result = 4        // Blurred result → Paywall
}

// MARK: - Style Category
enum StyleCategory: String, CaseIterable {
    case men = "Men"
    case women = "Women"
}

// MARK: - Style Preference
struct StylePreference: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let image: String? // Optional image name
}

extension StylePreference {
    static let menStyles: [StylePreference] = [
        StylePreference(name: "Textured Crop", icon: "scissors", image: "textured-crop"),
        StylePreference(name: "Low Fade", icon: "square.split.diagonal", image: "low-fade"),
        StylePreference(name: "Natural Flow", icon: "wind", image: "natural-flow"),
        StylePreference(name: "Classic Side Part", icon: "arrow.left.and.right", image: "classic-side-part"),
        StylePreference(name: "Modern Slick Back", icon: "arrow.up", image: "modern-slick-back"),
        StylePreference(name: "Clean Cut", icon: "checkmark.circle", image: "clean-cut"),
    ]
    
    static let womenStyles: [StylePreference] = [
        StylePreference(name: "Blowout", icon: "wind", image: "blowout"),
        StylePreference(name: "Curly Volume", icon: "circle.grid.3x3.fill", image: "curly-volume"),
        StylePreference(name: "Lob", icon: "scissors", image: "lob"),
        StylePreference(name: "Sleek Bun", icon: "circle.fill", image: "sleek-bun"),
        StylePreference(name: "Sleek Long", icon: "arrow.down", image: "sleek-long"),
        StylePreference(name: "Soft Waves", icon: "water.waves", image: "soft-waves"),
    ]
}

// MARK: - Onboarding View
struct OnboardingView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var authService = AuthService.shared
    
    @State private var currentStep: OnboardingStep = .styleFit
    @State private var selectedCategory: StyleCategory?
    @State private var selectedStyle: StylePreference?
    @State private var capturedImage: UIImage?
    @State private var generatedImage: UIImage?
    @State private var showCamera = false
    @State private var isProcessing = false
    @State private var showPaywall = false
    
    var body: some View {
        ZStack {
            // Aurora background
            AnimatedDarkGradient()
                .ignoresSafeArea()
            
            // Content based on step
            switch currentStep {
            case .styleFit:
                styleFitView
            case .intention:
                intentionView
            case .loading:
                loadingView
            case .result:
                resultView
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(appState)
        }
        .onChange(of: appState.capturedImage) { _, newImage in
            if newImage != nil && showCamera {
                capturedImage = newImage
                showCamera = false
                // Move to loading
                withAnimation(.haloSmooth) {
                    currentStep = .loading
                }
                // Start processing
                Task {
                    await processImage()
                }
            }
        }
        .onAppear {
            // If user is coming back from paywall and has already selected styles, go to "Styles Ready"
            let savedStyles = OnboardingDataService.shared.getLikedStyles()
            if !savedStyles.isEmpty {
                // Restore category
                if let categoryString = OnboardingDataService.shared.localData.styleCategory {
                    selectedCategory = StyleCategory(rawValue: categoryString.capitalized)
                }
                // Go directly to intention view (which will show "Styles Ready")
                currentStep = .intention
            }
        }
    }
    
    // MARK: - VIEW 1: Style Fit
    private var styleFitView: some View {
        VStack(spacing: 0) {
            // Headline - en haut
            Text("Which styles fit you best?")
                .font(.halo.displayLarge)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 80)
                .padding(.bottom, 40)
            
            Spacer()
            
            // Cards - Vertical (Men above, Women below)
            VStack(spacing: 12) {
                StyleFitCard(
                    title: "Men",
                    imageName: "men",
                    isSelected: selectedCategory == .men
                ) {
                    HapticManager.shared.buttonPress()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = .men
                    }
                }
                
                StyleFitCard(
                    title: "Women",
                    imageName: "women",
                    isSelected: selectedCategory == .women
                ) {
                    HapticManager.shared.buttonPress()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = .women
                    }
                }
            }
            .padding(.horizontal, 40)
            
            // CTA - Fixed at bottom with space from cards
            if selectedCategory != nil {
                Button {
                    HapticManager.shared.buttonPress()
                    saveCategorySelection() // Save to Supabase
                    withAnimation(.haloSmooth) {
                        currentStep = .intention
                    }
                } label: {
                    Group {
                        if #available(iOS 26.0, *) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .glassEffect(.regular, in: .capsule)
                        } else {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.white, in: Capsule())
                        }
                    }
                    .contentShape(Capsule())
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
        // Check if already finished (cards swiped) OR if coming back from paywall with saved styles
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
                            // Visual Card
                            VStack {
                                if let imageName = style.image {
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Color.gray.opacity(0.3)
                                        .overlay(
                                            Image(systemName: style.icon)
                                                .font(.system(size: 50))
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .frame(width: 220, height: 320) // Agrandissement significatif
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                            .rotationEffect(.degrees(Double(index - 1) * 6)) // Rotation plus subtile mais présente
                            .offset(x: CGFloat(index - 1) * 30, y: CGFloat(abs(index - 1)) * 10) // Plus d'espace
                            .scaleEffect(1.0 - (CGFloat(abs(index - 1)) * 0.05))
                            .zIndex(Double(count - index)) // Order: Top cards first ? No, stack order.
                            // Fix Z-Index logic: We want the middle or last card on top?
                            // Usually a stack implies top is last added or first array item.
                            // Let's optimize: Middle card (index 1) on top if 3 cards.
                            .zIndex(index == 1 ? 10 : 0)
                        }
                    }
                    .frame(height: 350)
                    .padding(.bottom, 20)
                        
                    VStack(spacing: 8) {
                        Text("Styles Ready")
                            .font(.halo.displayMedium)
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
                    // Headline - en haut
                    VStack(spacing: 8) {
                        Text("Swipe the styles you like")
                            .font(.halo.displayLarge)
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
                                .offset(y: CGFloat(index - currentCardIndex) * 8)
                                .scaleEffect(index == currentCardIndex ? 1.0 : 0.95)
                                .opacity(index == currentCardIndex ? 1.0 : 0.6)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Action buttons (Like / Skip)
                    HStack(spacing: 40) {
                        // Skip button (Clear Glass)
                        Button {
                            HapticManager.light()
                            skipCurrentCard()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .bold)) // Bold
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 72, height: 72)
                                .glassButtonCircle(color: .white.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Like button (Red Glass)
                        Button {
                            HapticManager.shared.buttonPress()
                            likeCurrentCard()
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 28, weight: .bold)) // Bold
                                .foregroundColor(.white)
                                .frame(width: 72, height: 72)
                                .glassButtonCircle(color: Color(red: 1.0, green: 0.2, blue: 0.4).opacity(0.25)) // Rouge teinté
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.bottom, 60)
                }
                .transition(.opacity)
            }
        }
    }
    
    @State private var currentCardIndex = 0
    @State private var likedStyles: [StylePreference] = []
    
    private func handleSwipe(direction: SwipeDirection, style: StylePreference) {
        if direction == .right {
            likedStyles.append(style)
            // Track like event
            Task {
                await OnboardingDataService.shared.trackEvent(
                    OnboardingDataService.EventName.styleSwipedLike,
                    data: ["style": style.name]
                )
            }
        } else {
            // Track skip event
            Task {
                await OnboardingDataService.shared.trackEvent(
                    OnboardingDataService.EventName.styleSwipedSkip,
                    data: ["style": style.name]
                )
            }
        }
        
        withAnimation(.spring(response: 0.3)) {
            currentCardIndex += 1
        }
        
        // Check if all cards swiped
        let styles = selectedCategory == .women ? StylePreference.womenStyles : StylePreference.menStyles
        if currentCardIndex >= styles.count {
            // Save liked styles locally
            OnboardingDataService.shared.saveLikedStyles(likedStyles)
            
            // Track event
            Task {
                await OnboardingDataService.shared.trackEvent(OnboardingDataService.EventName.allStylesSwiped)
            }
            
            // Transition to Camera directly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCamera = true
            }
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
    
    // MARK: - Save Category Selection (Local First)
    private func saveCategorySelection() {
        guard let category = selectedCategory else { return }
        OnboardingDataService.shared.saveStyleCategory(category)
        
        // Track event async
        Task {
            await OnboardingDataService.shared.trackEvent(
                OnboardingDataService.EventName.styleCategorySelected,
                data: ["category": category.rawValue]
            )
        }
    }
    
    // MARK: - VIEW 3: Selfie
    private var selfieView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Headline
            VStack(spacing: 12) {
                Text("Take a selfie")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Good lighting works best.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 40)
            
            // Camera preview placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 280, height: 380)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Privacy note
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                Text("Your photo stays private.")
                    .font(.system(size: 13))
            }
            .foregroundColor(.white.opacity(0.5))
            .padding(.top, 24)
            
            Spacer()
            
            // CTA
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
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - VIEW 4: Loading
    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Captured image preview
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        // Shimmer overlay
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.1), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            } else {
                // Skeleton
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 280)
            }
            
            // Headline
            VStack(spacing: 8) {
                Text("Creating your preview…")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Adapting the style to your face.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 32)
            
            // Loading indicator
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
                .padding(.top, 24)
            
            Spacer()
        }
    }
    
    // MARK: - VIEW 5: Result (Blurred)
    private var resultView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Blurred result
            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 280, height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .blur(radius: 20) // Blurred!
                    .overlay(
                        // Lock icon
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                    )
            } else if let image = capturedImage {
                // Fallback to captured image if generation failed
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 280, height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .blur(radius: 20)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
            
            // Headline
            VStack(spacing: 8) {
                Text("Your result is ready")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("See the full preview in Halo Studio")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 32)
            
            Spacer()
            
            // CTA - Opens Paywall
            Button {
                HapticManager.shared.buttonPress()
                showPaywall = true
            } label: {
                Text("Unlock Preview")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white, in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Process Image (FAKE - no API call)
    private func processImage() async {
        guard capturedImage != nil else { return }
        
        // FAKE loading - NO API call here!
        // Just simulate processing for UX
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
        
        // Trigger App Store review request during loading
        await MainActor.run {
            requestAppReview()
        }
        
        // Continue fake loading
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s more
        
        // Show blurred result (using captured image - no generation yet)
        await MainActor.run {
            generatedImage = capturedImage // Just use the selfie (will be blurred)
            withAnimation(.haloSmooth) {
                currentStep = .result
            }
        }
    }
    
    // MARK: - Request App Review
    private func requestAppReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
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
                // Image 4:5 aspect ratio
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4/5, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                
                // Title
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
        .animation(.spring(response: 0.3), value: isSelected)
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
                Image(systemName: style.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .black : .white)
                
                Text(style.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Swipe Direction
enum SwipeDirection {
    case left   // Skip
    case right  // Like
}

// MARK: - Swipe Card (Tinder-style)
struct SwipeCard: View {
    let style: StylePreference
    let isTopCard: Bool
    let onSwipe: (SwipeDirection) -> Void
    
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background - Image or glass fallback
            if let imageName = style.image {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                
                // Gradient overlay for text
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            } else {
                // Fallback - glass card with icon
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .aspectRatio(9/16, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: style.icon)
                                .font(.system(size: 60, weight: .light))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            }
            
            // Border
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            
            // Style name at bottom
            Text(style.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                .padding(.bottom, 32)
            
            // Like/Skip indicators
            if isDragging {
                // Like indicator (right swipe)
                if offset.width > 20 {
                    VStack {
                        Text("LIKE")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.green)
                            .padding(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.green, lineWidth: 4)
                            )
                            .rotationEffect(.degrees(-15))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(32)
                    .opacity(min(offset.width / swipeThreshold, 1.0))
                }
                
                // Skip indicator (left swipe)
                if offset.width < -20 {
                    VStack {
                        Text("NOPE")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.red)
                            .padding(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.red, lineWidth: 4)
                            )
                            .rotationEffect(.degrees(15))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(32)
                    .opacity(min(-offset.width / swipeThreshold, 1.0))
                }
            }
        }
        .aspectRatio(9/16, contentMode: .fit)
        .offset(x: offset.width, y: offset.height * 0.3)
        .rotationEffect(.degrees(Double(offset.width / 20)))
        .gesture(
            isTopCard ? DragGesture()
                .onChanged { gesture in
                    isDragging = true
                    offset = gesture.translation
                }
                .onEnded { gesture in
                    isDragging = false
                    
                    if gesture.translation.width > swipeThreshold {
                        // Swipe right - Like
                        withAnimation(.spring(response: 0.3)) {
                            offset = CGSize(width: 500, height: 0)
                        }
                        HapticManager.shared.buttonPress()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onSwipe(.right)
                        }
                    } else if gesture.translation.width < -swipeThreshold {
                        // Swipe left - Skip
                        withAnimation(.spring(response: 0.3)) {
                            offset = CGSize(width: -500, height: 0)
                        }
                        HapticManager.light()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onSwipe(.left)
                        }
                    } else {
                        // Return to center
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = .zero
                        }
                    }
                }
            : nil
        )
        .animation(.spring(response: 0.3), value: offset)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

// MARK: - Glass Button Circle Extension
extension View {
    @ViewBuilder
    func glassButtonCircle(color: Color) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(Circle().fill(color))
                .glassEffect(.regular.interactive(), in: Circle()) // Official Interactive API
                .contentShape(Circle())
        } else {
            self
                .background(
                    Circle()
                        .fill(color)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .contentShape(Circle())
        }
    }
}
