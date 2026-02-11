//
//  ResultView.swift
//  Eclat
//
//  Result screen - INSANE reveal experience
//  Transforms an image into identity confirmation
//

import SwiftUI

struct ResultView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    // Reveal animation states
    @State private var revealPhase: RevealPhase = .suspense
    @State private var imageBlur: CGFloat = 25
    @State private var imageScale: CGFloat = 1.05
    @State private var showContent = false
    @State private var showSavedToast = false
    @State private var showPushPermission = false
    
    // Rubber band drag
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Like animation
    @State private var isLiked = false
    @State private var likeScale: CGFloat = 1.0
    @State private var showLikeParticles = false
    
    enum RevealPhase {
        case suspense   // Blurred + zoomed
        case revealing  // Transition
        case revealed   // Full result
    }
    
    // Simple logic: blur if user has no Looks (uses subscriptionManager for combined logic)
    private var isBlurred: Bool {
        !subscriptionManager.hasLooks
    }
    
    // Image to display
    private var displayImage: UIImage? {
        appState.generatedImage ?? appState.capturedImage
    }
    
    // Tagline for the style (identity-driven micro-copy)
    private var styleTagline: String {
        guard let style = appState.selectedHairstyle else { return "" }
        
        // Map styles to taglines (can be extended)
        let taglines: [String: String] = [
            "clean girl bun": "The effortless classic.",
            "butterfly cut": "Bold. Flowy. Unforgettable.",
            "beach waves": "Casual confidence.",
            "90s blowout": "Volume that turns heads.",
            "curtain bangs": "Soft. Framing. Timeless.",
            "sleek middle part": "Minimal. Polished. Powerful.",
            "modern shag": "Texture with attitude.",
            "messy bun": "Effortlessly undone.",
            "balayage": "Sun-kissed dimension.",
            "platinum blonde": "Bold and iconic."
        ]
        
        let styleName = style.name.lowercased()
        return taglines[styleName] ?? "A look that fits."
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            if isBlurred {
                // BLURRED STATE - Premium paywall teaser
                blurredResultView
            } else {
                // UNLOCKED STATE - Full reveal experience
                revealResultView
            }
            
            // Saved toast
            if showSavedToast {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved to Photos")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8), in: Capsule())
                    
                    Spacer()
                }
                .padding(.top, 80)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            if !isBlurred {
                startRevealAnimation()
            }
        }
        // Push Permission Prompt (after save/share win moment)
        .sheet(isPresented: $showPushPermission) {
            PushPermissionView(segment: MonetizationEngine.shared.currentSegment)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
    }
    
    // MARK: - Reveal Animation Sequence
    private func startRevealAnimation() {
        // Phase 1: Suspense (already set by default)
        
        // Phase 2: Reveal after 0.8s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.6)) {
                revealPhase = .revealing
                imageBlur = 0
                imageScale = 1.0
            }
            
            // Haptic on reveal
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        }
        
        // Phase 3: Show content after reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.15)) {
                revealPhase = .revealed
                showContent = true
            }
            
            // Schedule retention notifications after first successful result
            NotificationManager.shared.scheduleAfterFirstResult()
            
            // Note: Push permission is now requested via PushPermissionView after Save/Share
        }
    }
    
    // MARK: - Reveal Result View (PLG/Viral Redesign)
    private var revealResultView: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Full image with reveal animation and rounded corners at bottom
            if let image = displayImage {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height - 100) // Leave space for bottom bar
                        .blur(radius: imageBlur)
                        .scaleEffect(imageScale)
                        .offset(y: rubberBandOffset)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 32,
                                bottomTrailingRadius: 32,
                                topTrailingRadius: 0
                            )
                        )
                        .overlay(
                            // Subtle gradient for readability
                            LinearGradient(
                                stops: [
                                    .init(color: Color.black.opacity(0.3), location: 0),
                                    .init(color: .clear, location: 0.15),
                                    .init(color: .clear, location: 0.85),
                                    .init(color: Color.black.opacity(0.3), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: 32,
                                    bottomTrailingRadius: 32,
                                    topTrailingRadius: 0
                                )
                            )
                        )
                        .gesture(rubberBandGesture)
                }
                .ignoresSafeArea(edges: .top)
            }
            
            // UI Overlay
            VStack {
                // Top bar - Back left, menu right
                HStack {
                    // Back button (left)
                    Button {
                        HapticManager.shared.buttonPress()
                        appState.navigateTo(.home)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassCircleButton()
                    
                    Spacer()
                    
                    // Menu button (right)
                    Button {
                        // Menu action placeholder
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassCircleButton()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
                
                // Suspense text (phase 1)
                if revealPhase == .suspense {
                    VStack {
                        Spacer()
                        Text("Your new look is ready")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 120)
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                
                // MARK: - Bottom Action Bar
                if showContent {
                    bottomActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    // MARK: - Bottom Action Bar (Reference UI Style)
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            // Left side: Like, Save, Share buttons
            HStack(spacing: 8) {
                // Like/Favorite button with animation
                Button {
                    toggleLike()
                } label: {
                    ZStack {
                        // Particle burst effect
                        if showLikeParticles {
                            ForEach(0..<8, id: \.self) { index in
                                Circle()
                                    .fill(Color(red: 1, green: 0.4, blue: 0.5).opacity(0.8))
                                    .frame(width: 6, height: 6)
                                    .offset(y: showLikeParticles ? -30 : 0)
                                    .rotationEffect(.degrees(Double(index) * 45))
                                    .opacity(showLikeParticles ? 0 : 1)
                            }
                        }
                        
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                isLiked 
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [Color(red: 1, green: 0.4, blue: 0.5), Color(red: 1, green: 0.3, blue: 0.4)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    : AnyShapeStyle(Color.white)
                            )
                            .scaleEffect(likeScale)
                    }
                    .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .glassCircleButton()
                
                // Save button
                Button {
                    saveToPhotos()
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
                .glassCircleButton()
                
                // Share button
                Button {
                    shareResult()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
                .glassCircleButton()
            }
            
            Spacer()
            
            // Right side: Try another style button
            Button {
                handleTryAnotherStyle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Try another style")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .glassRoundedButton()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
    
    // MARK: - Like Animation
    private func toggleLike() {
        // Strong haptic
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        if !isLiked {
            // Animate to liked state
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                isLiked = true
                likeScale = 1.3
            }
            
            // Show particles
            showLikeParticles = true
            withAnimation(.easeOut(duration: 0.5)) {
                showLikeParticles = true
            }
            
            // Scale back down
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    likeScale = 1.0
                }
            }
            
            // Hide particles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showLikeParticles = false
            }
            
            // Second haptic for satisfaction
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let soft = UIImpactFeedbackGenerator(style: .soft)
                soft.impactOccurred(intensity: 0.5)
            }
        } else {
            // Unlike with subtle animation
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isLiked = false
                likeScale = 0.8
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    likeScale = 1.0
                }
            }
        }
    }
    
    // MARK: - Post-Result Action Handler
    private func handleTryAnotherStyle() {
        HapticManager.shared.buttonPress()
        
        // Check if user has looks available
        if subscriptionManager.hasLooks {
            // Has looks → Go to camera
            appState.navigateTo(.home)
            appState.showCameraSheet = true
        } else {
            // No looks → Show paywall
            appState.showPaywall()
        }
    }
    
    // MARK: - Rubber Band Effect
    private var rubberBandOffset: CGFloat {
        if dragOffset > 0 {
            // Rubber band resistance when pulling down
            return dragOffset * 0.3
        }
        return 0
    }
    
    private var rubberBandGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.height
            }
            .onEnded { value in
                isDragging = false
                
                // If dragged down significantly, dismiss
                if value.translation.height > 150 {
                    HapticManager.shared.buttonPress()
                    appState.navigateTo(.home)
                } else {
                    // Snap back with haptic
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7, blendDuration: 0.1)) {
                        dragOffset = 0
                    }
                }
            }
    }
    
    // MARK: - Blurred Result View (Premium Teaser)
    private var blurredResultView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Spacer()
                
                Button {
                    HapticManager.shared.buttonPress()
                    appState.navigateTo(.home)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                }
                .glassCircleButton()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Spacer()
            
            // Blurred photo card
            if let image = displayImage {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 380)
                        .blur(radius: 25)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
                }
            }
            
            Spacer()
            
            // Bottom section
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 6) {
                    Text("Your look is ready")
                        .font(.eclat.displayMedium)
                        .foregroundColor(.white)
                    
                    Text("Unlock to see your transformation")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // CTA Button
                Button {
                    print("🔴 ResultView: Opening paywall")
                    appState.showPaywall()
                } label: {
                    Text("Unlock My Looks")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white, in: Capsule())
                }
                .padding(.horizontal, 24)
                .buttonStyle(ResultScaleButtonStyle())
                
                // Subtitle
                Text("Subscribe to see your look")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Save
    private func saveToPhotos() {
        guard let image = displayImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        HapticManager.success()
        TikTokService.shared.trackDownload(contentId: appState.selectedHairstyle?.id.uuidString ?? "unknown")
        
        withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15)) {
                showSavedToast = false
            }
            
            // Show push permission after save (win moment)
            if NotificationManager.shared.shouldShowPermissionPrompt() {
                showPushPermission = true
            }
        }
    }
    
    // MARK: - Share (PLG Boost)
    private func shareResult() {
        guard let originalImage = displayImage else { return }
        HapticManager.shared.buttonPress()
        TikTokService.shared.trackShare(contentType: "hairstyle_result", contentId: appState.selectedHairstyle?.id.uuidString ?? "unknown")
        
        // Create watermarked image for virality
        let watermarkedImage = addWatermark(to: originalImage)
        
        // Share text with App Store link for K-factor
        let shareText = "I tried this hairstyle with Eclat ✨\n\nTry yours: https://apps.apple.com/app/id6740513787"
        
        let activityVC = UIActivityViewController(
            activityItems: [watermarkedImage, shareText],
            applicationActivities: nil
        )
        
        // Exclude some activities that don't make sense
        activityVC.excludedActivityTypes = [.assignToContact, .addToReadingList, .openInIBooks]
        
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                // Show push permission after share (win moment)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if NotificationManager.shared.shouldShowPermissionPrompt() {
                        self.showPushPermission = true
                    }
                }
            }
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Add Watermark (PLG)
    private func addWatermark(to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)
            
            // Watermark text
            let watermarkText = "Eclat"
            let fontSize = max(image.size.width * 0.04, 24) // Responsive font size
            
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .shadow: {
                    let shadow = NSShadow()
                    shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
                    shadow.shadowBlurRadius = 4
                    shadow.shadowOffset = CGSize(width: 0, height: 2)
                    return shadow
                }()
            ]
            
            let textSize = watermarkText.size(withAttributes: textAttributes)
            
            // Position: bottom center with padding
            let padding: CGFloat = image.size.width * 0.04
            let textX = (image.size.width - textSize.width) / 2  // Centered horizontally
            let textY = image.size.height - textSize.height - padding
            
            watermarkText.draw(at: CGPoint(x: textX, y: textY), withAttributes: textAttributes)
        }
    }
}

// MARK: - Glass Button Styles
extension View {
    @ViewBuilder
    func glassCircleButton() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            self
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                )
        }
    }
    
    @ViewBuilder
    func glassRoundedButton() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                )
        }
    }
    
    @ViewBuilder
    func glassCardBackground() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(.ultraThinMaterial.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, y: -10)
                )
        }
    }
}

// MARK: - Premium Button Style (Scale + Blur + Haptic)
// MARK: - Premium Button Style (Scale + Blur + Haptic)
struct ResultScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .blur(radius: configuration.isPressed ? 2 : 0)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    let impact = UIImpactFeedbackGenerator(style: .soft)
                    impact.impactOccurred(intensity: 1.0)
                }
            }
    }
}

#Preview {
    ResultView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
}
