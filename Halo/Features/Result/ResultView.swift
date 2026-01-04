//
//  ResultView.swift
//  Halo
//
//  Result screen
//

import SwiftUI

struct ResultView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var showComparison = false
    @State private var showSavedToast = false
    
    private var isBlurred: Bool {
        !subscriptionManager.isSubscribed
    }
    
    var body: some View {
        ZStack {
            LinearGradient.haloBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    HaloIconButton(icon: "xmark") {
                        appState.startNewTryOn()
                    }
                    
                    Spacer()
                    
                    Text("Your New Look")
                        .font(.halo.headlineSmall)
                        .foregroundColor(.theme.textPrimary)
                    
                    Spacer()
                    
                    if !isBlurred {
                        HaloIconButton(icon: "square.and.arrow.up") {
                            shareResult()
                        }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                
                Spacer()
                
                // Result image
                VStack(spacing: Spacing.lg) {
                    ZStack {
                        if let image = appState.generatedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 280, height: 380)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                                .blur(radius: isBlurred ? 25 : 0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .strokeBorder(LinearGradient.haloPrimary, lineWidth: 1.5)
                                )
                                .overlay {
                                    if isBlurred { lockedOverlay }
                                }
                        }
                    }
                    
                    if let hairstyle = appState.selectedHairstyle {
                        VStack(spacing: Spacing.xs) {
                            Text(hairstyle.name)
                                .font(.halo.headlineLarge)
                                .foregroundColor(.theme.textPrimary)
                            
                            HaloChip(hairstyle.category.rawValue, icon: "tag.fill", isSelected: true)
                        }
                    }
                    
                    if !isBlurred {
                        HaloSecondaryButton(showComparison ? "Hide Original" : "Compare", icon: "arrow.left.arrow.right") {
                            withAnimation(.haloSmooth) {
                                showComparison.toggle()
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Bottom CTA
                VStack(spacing: Spacing.md) {
                    if isBlurred {
                        HaloCTAButton("Unlock Full Result") {
                            appState.navigateTo(.paywall)
                        }
                        
                        Button("Try Another Style") {
                            appState.startNewTryOn()
                        }
                        .font(.halo.labelMedium)
                        .foregroundColor(.theme.textSecondary)
                    } else {
                        HaloCTAButton("Save to Photos", icon: "arrow.down.to.line") {
                            saveToPhotos()
                        }
                        
                        HaloSecondaryButton("Try Another Style", icon: "arrow.counterclockwise") {
                            appState.startNewTryOn()
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            
            // Saved toast
            if showSavedToast {
                VStack {
                    Spacer()
                    
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.theme.success)
                        Text("Saved to Photos")
                            .font(.halo.labelMedium)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(.regularMaterial, in: Capsule())
                    
                    Spacer().frame(height: 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var lockedOverlay: some View {
        VStack(spacing: Spacing.md) {
            Circle()
                .fill(Color.theme.glassFill)
                .frame(width: 70, height: 70)
                .overlay(
                    Circle().strokeBorder(LinearGradient.haloPrimary, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(LinearGradient.haloPrimary)
                )
            
            VStack(spacing: Spacing.xs) {
                Text("Unlock Your Look")
                    .font(.halo.headlineSmall)
                    .foregroundColor(.white)
                
                Text("Subscribe to see your\namazing transformation")
                    .font(.halo.bodySmall)
                    .foregroundColor(.theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func saveToPhotos() {
        guard let image = appState.generatedImage else { return }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        HapticManager.success()
        
        withAnimation(.haloSmooth) {
            showSavedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.haloSmooth) {
                showSavedToast = false
            }
        }
    }
    
    private func shareResult() {
        guard let image = appState.generatedImage else { return }
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    ResultView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}
