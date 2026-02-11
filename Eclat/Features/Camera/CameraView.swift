//
//  CameraView.swift
//  Eclat
//
//  Premium Camera Experience - Apple/Snap/Instagram Level
//  This view is CRITICAL - it's the point of truth for the entire app.
//

import SwiftUI
import PhotosUI

// MARK: - Face Detection State
enum FaceState: Equatable {
    case searching       // No face detected
    case adjusting       // Face detected but not centered
    case ready           // Face perfectly positioned
    case capturing       // Photo being taken
}

// MARK: - Glass Circle Modifier
extension View {
    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .clipShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }
    
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self
                .clipShape(Capsule())
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct CameraView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var cameraService = CameraService()
    @Environment(\.dismiss) private var dismiss
    
    // UI State
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingPhotoItem: PhotosPickerItem?
    @State private var showStyleSheet = false
    @State private var showInstructions = false
    
    // Camera Experience State
    @State private var faceState: FaceState = .searching
    @State private var guidanceText: String = "Center your face"
    @State private var showGuidance = true
    @State private var isCharging = false          // Intent lock animation
    @State private var chargeProgress: CGFloat = 0
    @State private var showSacredMoment = false    // "This is your canvas"
    @State private var capturedImage: UIImage?     // For post-capture transition
    @State private var showCapturedPreview = false
    @State private var backgroundBlur: CGFloat = 0 // Blur disabled - was confusing users
    
    // Breathing animation for oval
    @State private var ovalBreathing = false
    @State private var ovalGlow = false
    
    // Timer for face simulation (needs cleanup)
    @State private var faceSimulationTimer: Timer?
    
    var body: some View {
        ZStack {
            // MARK: - Camera Preview with Reward Blur
            // Blur when not centered → Clear when perfect (reward mechanism)
            Group {
                if cameraService.isCameraReady {
                    CameraPreviewView(session: cameraService.session)
                        // Blur removed - was confusing users
                } else {
                    Color.black
                }
            }
            .ignoresSafeArea()
            
            // MARK: - Post-capture freeze frame
            if showCapturedPreview, let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.02)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // MARK: - Adaptive Face Guide (Living Oval)
            adaptiveFaceGuide
            
            // MARK: - Subtle Guidance Text
            if showGuidance && !showCapturedPreview {
                guidanceTextView
            }
            
            // MARK: - Sacred Moment Text
            if showSacredMoment {
                sacredMomentView
            }
            
            // MARK: - Controls Overlay
            if !showCapturedPreview {
                controlsOverlay
            }
        }
        .sheet(isPresented: $showStyleSheet) {
            StylePickerSheet(selectedStyle: $appState.selectedHairstyle)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task { await loadPhoto(newValue) }
        }
        .onChange(of: appState.selectedHairstyle) { _, newStyle in
            if newStyle != nil, let pending = pendingPhotoItem {
                pendingPhotoItem = nil
                Task { await loadPhoto(pending) }
            }
        }
        .sheet(isPresented: $showInstructions) {
            InstructionSheetView(showInstructions: $showInstructions)
                .presentationDetents([.fraction(0.4), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground {
                    if #available(iOS 26.0, *) {
                        Rectangle()
                            .fill(.clear)
                            .glassEffect(.regular, in: Rectangle())
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }
                }
                .interactiveDismissDisabled(false)
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasSeenCameraInstructions") {
                showInstructions = true
            }
            TikTokService.shared.trackCameraOpened()
            Task {
                await cameraService.checkAuthorization()
                cameraService.startSession()
            }
            startFaceSimulation()
            startOvalBreathing()
        }
        .onDisappear {
            // CRITICAL: Stop camera and timer when view disappears
            cameraService.stopSession()
            faceSimulationTimer?.invalidate()
            faceSimulationTimer = nil
        }
    }
    
    // MARK: - Adaptive Face Guide
    private var adaptiveFaceGuide: some View {
        GeometryReader { geo in
            let baseWidth = geo.size.width * 0.65
            let baseHeight = baseWidth * 1.35
            
            // Dynamic sizing based on face state
            let sizeMultiplier: CGFloat = {
                switch faceState {
                case .searching: return 1.0
                case .adjusting: return 0.98
                case .ready: return 0.96
                case .capturing: return 0.94
                }
            }()
            
            let width = baseWidth * sizeMultiplier * (ovalBreathing ? 1.005 : 1.0)
            let height = baseHeight * sizeMultiplier * (ovalBreathing ? 1.005 : 1.0)
            
            // Dynamic opacity
            let strokeOpacity: Double = {
                switch faceState {
                case .searching: return 0.2
                case .adjusting: return 0.4
                case .ready: return 0.8
                case .capturing: return 1.0
                }
            }()
            
            // Dynamic stroke width
            let strokeWidth: CGFloat = {
                switch faceState {
                case .searching: return 1
                case .adjusting: return 1.5
                case .ready: return 2
                case .capturing: return 2.5
                }
            }()
            
            ZStack {
                // Glow layer (only when ready)
                if faceState == .ready || ovalGlow {
                    Ellipse()
                        .stroke(Color.white.opacity(0.15), lineWidth: 8)
                        .blur(radius: 8)
                        .frame(width: width + 4, height: height + 4)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.4)
                }
                
                // Main oval
                Ellipse()
                    .strokeBorder(
                        Color.white.opacity(strokeOpacity),
                        lineWidth: strokeWidth
                    )
                    .frame(width: width, height: height)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.4)
            }
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15), value: faceState)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: ovalBreathing)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Guidance Text View
    private var guidanceTextView: some View {
        VStack {
            Spacer()
            
            Text(guidanceText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3), in: Capsule())
                .padding(.bottom, 200)
                .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                .animation(.easeInOut(duration: 0.6), value: guidanceText)
        }
    }
    
    // MARK: - Sacred Moment View
    private var sacredMomentView: some View {
        VStack {
            Spacer()
            
            Text("This is your canvas.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 200)
                .transition(.opacity)
        }
    }
    
    // MARK: - Controls Overlay
    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    HapticManager.shared.buttonPress()
                    cameraService.stopSession()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .glassCircle()
                }
                
                Spacer()
                
                // Title area - Eclat or Style Name
                VStack(spacing: 4) {
                    Text("Eclat")
                        .font(.eclat.displaySmall)
                        .foregroundColor(.white)
                    
                    // Style name as subtitle when selected
                    if let style = appState.selectedHairstyle {
                        Text(style.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15), value: appState.selectedHairstyle?.id)
                
                Spacer()
                
                Button {
                    HapticManager.shared.buttonPress()
                    cameraService.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .glassCircle()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            
            Spacer()
            
            // Bottom section
            VStack(spacing: Spacing.lg) {
                // Only show "Choose a style" button when no style selected
                if appState.selectedHairstyle == nil {
                    Button {
                        HapticManager.shared.buttonPress()
                        showStyleSheet = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "sparkles")
                            Text("Choose a style")
                        }
                        .font(.eclat.labelMedium)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .glassCapsule()
                    }
                }
                
                // Capture row
                HStack(spacing: 50) {
                    // Gallery button
                    Button {
                        HapticManager.shared.buttonPress()
                        showingPhotoPicker = true
                    } label: {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .glassCircle()
                    }
                    
                    // MARK: - Magnetic Capture Button with Intent Lock
                    magneticCaptureButton
                    
                    // Styles button (icon changed from wand to sliders)
                    Button {
                        HapticManager.shared.buttonPress()
                        showStyleSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .glassCircle()
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Magnetic Capture Button
    private var magneticCaptureButton: some View {
        Button {
            // Intent lock - don't capture immediately
        } label: {
            ZStack {
                // Background glass circle
                Circle()
                    .fill(.clear)
                    .frame(width: 100, height: 100)
                    .glassCircle()
                
                // Charge progress ring
                if isCharging {
                    Circle()
                        .trim(from: 0, to: chargeProgress)
                        .stroke(
                            Color.white.opacity(0.8),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                }
                
                // Inner white circle with glow
                Circle()
                    .fill(.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: .white.opacity(faceState == .ready ? 0.3 : 0), radius: 8)
                    .scaleEffect(isCharging ? 0.92 : 1)
            }
            .scaleEffect(isCharging ? 0.94 : 1)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7, blendDuration: 0.1), value: isCharging)
        }
        .buttonStyle(MagneticButtonStyle())
        .disabled(cameraService.isCapturing || appState.selectedHairstyle == nil)
        .opacity(appState.selectedHairstyle == nil ? 0.4 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isCharging && appState.selectedHairstyle != nil {
                        startIntentLock()
                    }
                }
                .onEnded { _ in
                    if isCharging {
                        completeCapture()
                    }
                }
        )
    }
    
    // MARK: - Intent Lock (0.4s charge before capture)
    private func startIntentLock() {
        guard !cameraService.isCapturing else { return }
        
        isCharging = true
        chargeProgress = 0
        
        // Soft haptic on press
        let impactLight = UIImpactFeedbackGenerator(style: .light)
        impactLight.impactOccurred()
        
        // Animate charge over 0.4s
        withAnimation(.linear(duration: 0.4)) {
            chargeProgress = 1.0
        }
    }
    
    private func completeCapture() {
        guard isCharging else { return }
        
        // Check if charge completed
        if chargeProgress >= 0.8 {
            // Strong haptic on complete
            let impactMedium = UIImpactFeedbackGenerator(style: .medium)
            impactMedium.impactOccurred()
            
            // Show sacred moment briefly
            withAnimation(.easeInOut(duration: 0.3)) {
                showGuidance = false
                showSacredMoment = true
            }
            
            // Take photo after sacred moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation {
                    showSacredMoment = false
                }
                Task { await captureWithTransition() }
            }
        } else {
            // Cancelled - reset
            withAnimation {
                isCharging = false
                chargeProgress = 0
            }
        }
        
        isCharging = false
    }
    
    // MARK: - Capture with Micro-transition
    private func captureWithTransition() async {
        guard appState.selectedHairstyle != nil else {
            showStyleSheet = true
            return
        }
        
        do {
            let image = try await cameraService.capturePhoto()
            
            // Store for preview
            capturedImage = image
            
            // Haptic on capture complete
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            // Micro-transition: freeze frame with slight zoom
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCapturedPreview = true
                }
            }
            
            // Brief pause to show frozen frame
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            // Track and navigate
            TikTokService.shared.trackSelfieCaptured()
            appState.setCapturedImage(image)
            
        } catch {
            appState.errorMessage = error.localizedDescription
            HapticManager.error()
        }
    }
    
    // MARK: - Face State Simulation (replace with real face detection later)
    private func startFaceSimulation() {
        // Cancel any existing timer first
        faceSimulationTimer?.invalidate()
        
        // Simulate face detection states for demo
        // In production, integrate with Vision framework
        
        faceSimulationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [self] _ in
            let states: [FaceState] = [.searching, .adjusting, .ready]
            let randomState = states.randomElement() ?? .adjusting
            
            Task { @MainActor in
                withAnimation {
                    faceState = randomState
                    updateGuidanceForState(randomState)
                    updateBlurForState(randomState)
                }
                
                // Haptic only when face becomes ready
                if randomState == .ready {
                    let impactSoft = UIImpactFeedbackGenerator(style: .soft)
                    impactSoft.impactOccurred()
                    
                    // Brief glow pulse
                    withAnimation(.easeInOut(duration: 0.3)) {
                        ovalGlow = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            ovalGlow = false
                        }
                    }
                }
            }
        }
    }
    
    private func updateGuidanceForState(_ state: FaceState) {
        switch state {
        case .searching:
            guidanceText = "Center your face"
        case .adjusting:
            guidanceText = "Hold still"
        case .ready:
            guidanceText = "Perfect"
        case .capturing:
            guidanceText = ""
        }
    }
    
    // Blur disabled - was confusing users
    private func updateBlurForState(_ state: FaceState) {
        // Blur removed entirely - always crystal clear
        backgroundBlur = 0
    }
    
    private func startOvalBreathing() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            ovalBreathing = true
        }
    }
    
    // MARK: - Load Photo from Gallery
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        guard appState.selectedHairstyle != nil else {
            pendingPhotoItem = item
            showStyleSheet = true
            return
        }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            TikTokService.shared.trackSelfieCaptured()
            appState.setCapturedImage(image)
        }
    }
}

// MARK: - Magnetic Button Style (feedback on release, not press)
struct MagneticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // No immediate feedback on press - handled by gesture
    }
}

// MARK: - Instruction Sheet Content
struct InstructionSheetView: View {
    @Binding var showInstructions: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("How to get the best result")
                .font(.title3.bold())
                .padding(.top, 24)
            
            HStack(spacing: 30) {
                InstructionItem(icon: "slider.horizontal.3", title: "Choose Style", subtitle: "Pick a look first")
                InstructionItem(icon: "face.smiling", title: "Face Forward", subtitle: "No glasses")
                InstructionItem(icon: "sun.max.fill", title: "Good Light", subtitle: "Avoid shadows")
            }
            
            Spacer()
            
            Button {
                UserDefaults.standard.set(true, forKey: "hasSeenCameraInstructions")
                showInstructions = false
            } label: {
                Text("I'm Ready")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black, in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

struct InstructionItem: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 50, height: 50)
                .background(Color.secondary.opacity(0.1), in: Circle())
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Style Picker Sheet
struct StylePickerSheet: View {
    @Binding var selectedStyle: Hairstyle?
    @State private var selectedCategory: GenderCategory = .women
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(GenderCategory.allCases, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Text(category.rawValue)
                                        .font(.eclat.labelMedium)
                                        .foregroundColor(selectedCategory == category ? .primary : .secondary)
                                        .padding(.horizontal, Spacing.md)
                                        .padding(.vertical, Spacing.sm)
                                        .background(
                                            selectedCategory == category ? Color.primary.opacity(0.1) : Color.clear,
                                            in: Capsule()
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                    
                    // Styles grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                        ForEach(HairstyleData.styles(for: selectedCategory)) { style in
                            Button {
                                selectedStyle = style
                                dismiss()
                            } label: {
                                VStack(spacing: Spacing.sm) {
                                    GeometryReader { geometry in
                                        ZStack {
                                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                                .fill(Color.secondary.opacity(0.1))
                                            
                                            if let imageName = style.imageName {
                                                Image(imageName)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                                    .clipped()
                                            } else {
                                                Image(systemName: "scissors")
                                                    .font(.title)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                                .strokeBorder(
                                                    selectedStyle?.id == style.id ? Color.primary : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                    .aspectRatio(3/4, contentMode: .fit)
                                    
                                    Text(style.name)
                                        .font(.eclat.labelSmall)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .padding(.vertical, Spacing.md)
            }
            .navigationTitle("Choose Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CameraView()
        .environmentObject(AppState())
        .environmentObject(CameraService())
        .preferredColorScheme(.dark)
}

// MARK: - Scale Button Style (Premium Touch)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .blur(radius: configuration.isPressed ? 0.5 : 0)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    // Touch down - soft haptic
                    HapticManager.shared.buttonPress()
                } else {
                    // Touch up - lighter haptic
                    HapticManager.shared.buttonRelease()
                }
            }
    }
}
