//
//  ProcessingView.swift
//  Halo
//
//  AI Processing screen - Shows loading then result in same page
//

import SwiftUI

struct ProcessingView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var progress: Double = 0
    @State private var currentPhase = 0
    @State private var shimmerOffset: CGFloat = -1
    @State private var hasError = false
    @State private var isComplete = false
    @State private var generatedImage: UIImage?
    @State private var showLocalPaywall = false
    
    private let phases = [
        "Analyzing your face...",
        "Matching facial features...",
        "Generating hairstyle...",
        "Applying final touches..."
    ]
    
    var body: some View {
        ZStack {
            // Modern animated background
            AnimatedDarkGradient()
            
            // Close button en haut à droite (quand complete)
            if isComplete {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            appState.startNewTryOn()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 40, height: 40)
                        }
                        .glassButtonStyle(style: .circle)
                        .padding(.top, 16)
                        .padding(.trailing, 24)
                    }
                    Spacer()
                }
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Image container - shows skeleton while loading, then result
                ZStack {
                    if isComplete, let image = generatedImage {
                        // Result image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 280, height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .transition(.opacity)
                    } else {
                        // Skeleton card avec shimmer diagonal (loading)
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 280, height: 380)
                            .overlay(
                                // Shimmer effect diagonal
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            stops: [
                                                .init(color: .clear, location: 0),
                                                .init(color: .clear, location: 0.35),
                                                .init(color: Color.white.opacity(0.03), location: 0.42),
                                                .init(color: Color.white.opacity(0.06), location: 0.47),
                                                .init(color: Color.white.opacity(0.08), location: 0.5),
                                                .init(color: Color.white.opacity(0.06), location: 0.53),
                                                .init(color: Color.white.opacity(0.03), location: 0.58),
                                                .init(color: .clear, location: 0.65),
                                                .init(color: .clear, location: 1)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .blur(radius: 25)
                                    .frame(width: 800, height: 800)
                                    .rotationEffect(.degrees(-45))
                                    .offset(x: shimmerOffset * 1000 - 500)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .transition(.opacity)
                    }
                }
                
                // Status text or hairstyle name
                if isComplete {
                    if let hairstyle = appState.selectedHairstyle {
                        VStack(spacing: 8) {
                            Text(hairstyle.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(hairstyle.category.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                } else {
                    Text(hasError ? "Something went wrong" : phases[currentPhase])
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(hasError ? .red : .white)
                        .animation(.easeInOut, value: currentPhase)
                }
                
                Spacer()
                
                // Action buttons en bas
                if isComplete {
                    HStack(spacing: 12) {
                        // Save to Photos button (glass clear)
                        Button {
                            saveToPhotos()
                        } label: {
                            Text("Save to Photos")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .glassButtonStyle(style: .clear)
                        
                        // Share button (glass white)
                        Button {
                            shareImage()
                        } label: {
                            Text("Share")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .glassButtonStyle(style: .white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                } else if !hasError {
                    // Cancel button (loading)
                    Button {
                        appState.reset()
                        appState.navigateTo(.home)
                        appState.showCameraSheet = true
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 120, height: 44)
                    }
                    .glassButtonStyle(style: .clear)
                    .padding(.bottom, 32)
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showLocalPaywall) {
            PaywallView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        .onChange(of: subscriptionManager.isSubscribed) { _, isSubscribed in
            if isSubscribed {
                showLocalPaywall = false
                if generatedImage == nil && !isComplete {
                    startProcessing()
                }
            }
        }
        .onChange(of: showLocalPaywall) { _, isPresented in
            if !isPresented && !subscriptionManager.isSubscribed {
                // User dismissed paywall without paying -> Return to home
                appState.navigateTo(.home)
            }
        }
        .onAppear {
            startProcessing()
            startShimmerAnimation()
        }
    }
    
    private func startShimmerAnimation() {
        shimmerOffset = 0
        withAnimation(
            Animation.easeInOut(duration: 2.0)
            .delay(0.3)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 1
        }
    }
    
    private func startProcessing() {
        Task {
            // Check Subscription
            if !subscriptionManager.isSubscribed {
                // Fake loading
                let fakeProgressTask = Task {
                    for i in 0..<40 {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                progress = Double(i) / 100.0
                                currentPhase = min(i / 25, phases.count - 1)
                            }
                        }
                    }
                }
                
                // Wait 2s then show Paywall
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                fakeProgressTask.cancel()
                
                await MainActor.run {
                    showLocalPaywall = true
                }
                return
            }
            
            let progressTask = Task {
                for i in 0..<100 {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            progress = Double(i) / 100.0
                            currentPhase = min(i / 25, phases.count - 1)
                        }
                    }
                }
            }
            
            guard let capturedImage = appState.capturedImage,
                  let hairstyle = appState.selectedHairstyle else {
                hasError = true
                progressTask.cancel()
                return
            }
            
            do {
                let generated = try await GeminiAPIService.shared.generateHairstyle(
                    from: capturedImage,
                    prompt: hairstyle.prompt
                )
                
                progressTask.cancel()
                
                await MainActor.run {
                    progress = 1.0
                }
                
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                await MainActor.run {
                    // Store in appState
                    appState.generatedImage = generated
                    
                    // Show in this view
                    withAnimation(.easeInOut(duration: 0.5)) {
                        generatedImage = generated
                        isComplete = true
                    }
                    
                    // Save to history
                    Task {
                        do {
                            _ = try await SupabaseStorageService.shared.saveGeneration(
                                image: generated,
                                styleName: hairstyle.name,
                                category: hairstyle.category.rawValue
                            )
                        } catch {
                            print("Failed to save to history: \(error)")
                        }
                    }
                }
                
            } catch {
                progressTask.cancel()
                
                await MainActor.run {
                    hasError = true
                    appState.errorMessage = error.localizedDescription
                    HapticManager.error()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        appState.navigateTo(.home)
                        appState.showCameraSheet = true
                    }
                }
            }
        }
    }
    
    private func saveToPhotos() {
        guard let image = generatedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        HapticManager.success()
    }
    
    private func shareImage() {
        guard let image = generatedImage else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    ProcessingView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}

// MARK: - Glass Button Style Extension
extension View {
    @ViewBuilder
    func glassButtonStyle(style: GlassStyle) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .clear:
                self
                    // Glass Only
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 25))
            case .white:
                self
                    // White tint + Glass
                    .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 25))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 25))
            case .circle:
                self
                    // Circular Glass
                    .glassEffect(.regular, in: Circle())
            }
        } else {
            // Fallback for iOS < 26
            switch style {
            case .clear:
                self
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            case .white:
                self
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white.opacity(0.9))
                    )
            case .circle:
                self
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }
}

enum GlassStyle {
    case clear
    case white
    case circle
}
