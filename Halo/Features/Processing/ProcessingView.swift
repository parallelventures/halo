//
//  ProcessingView.swift
//  Halo
//
//  AI Processing screen
//

import SwiftUI

struct ProcessingView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var progress: Double = 0
    @State private var currentPhase = 0
    @State private var scanOffset: CGFloat = -1
    @State private var hasError = false
    
    private let phases = [
        "Analyzing your face...",
        "Matching facial features...",
        "Generating hairstyle...",
        "Applying final touches..."
    ]
    
    var body: some View {
        ZStack {
            LinearGradient.haloBackground
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.xxl) {
                Spacer()
                
                // Image preview
                ZStack {
                    if let image = appState.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                            .overlay(
                                // Scan line
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, Color.theme.accentPrimary.opacity(0.4), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: 60)
                                    .offset(y: scanOffset * 125)
                                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.lg)
                                    .strokeBorder(LinearGradient.haloPrimary, lineWidth: 1.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .fill(Color.theme.glassFill)
                            .frame(width: 200, height: 250)
                            .overlay(ProgressView())
                    }
                }
                
                // Progress
                VStack(spacing: Spacing.lg) {
                    Text(hasError ? "Something went wrong" : phases[currentPhase])
                        .font(.halo.headlineSmall)
                        .foregroundColor(hasError ? .theme.error : .theme.textPrimary)
                        .animation(.haloSmooth, value: currentPhase)
                    
                    VStack(spacing: Spacing.sm) {
                        ProgressView(value: progress)
                            .tint(Color.theme.accentPrimary)
                            .frame(width: 200)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.halo.labelMedium)
                            .foregroundColor(.theme.textSecondary)
                            .monospacedDigit()
                    }
                    
                    if let hairstyle = appState.selectedHairstyle {
                        HaloChip(hairstyle.name, icon: "sparkles", isSelected: true)
                    }
                }
                
                Spacer()
                
                HaloSecondaryButton("Cancel", icon: "xmark") {
                    appState.reset()
                    appState.navigateTo(.camera)
                }
                .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .onAppear {
            startProcessing()
            startScanAnimation()
        }
    }
    
    private func startScanAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            scanOffset = 1
        }
    }
    
    private func startProcessing() {
        Task {
            let progressTask = Task {
                for i in 0..<100 {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    await MainActor.run {
                        withAnimation(.haloSmooth) {
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
                let generatedImage = try await GeminiAPIService.shared.generateHairstyle(
                    from: capturedImage,
                    prompt: hairstyle.prompt
                )
                
                progressTask.cancel()
                
                await MainActor.run {
                    progress = 1.0
                }
                
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                await MainActor.run {
                    appState.setGeneratedImage(generatedImage)
                }
                
            } catch {
                progressTask.cancel()
                
                await MainActor.run {
                    hasError = true
                    appState.errorMessage = error.localizedDescription
                    HapticManager.error()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        appState.navigateTo(.camera)
                    }
                }
            }
        }
    }
}

#Preview {
    ProcessingView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}
