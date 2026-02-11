//
//  PostPaywallOnboarding.swift
//  Eclat
//
//  Post-paywall onboarding - 3 sheets flow
//

import SwiftUI

struct PostPaywallOnboarding: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @State private var currentStep: OnboardingStep = .welcome
    
    enum OnboardingStep {
        case welcome
        case guidelines
        case activation
    }
    
    var body: some View {
        sheetContent
    }
    
    @ViewBuilder
    private var sheetContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeSheet(onNext: {
                withAnimation {
                    currentStep = .guidelines
                }
            })
        case .guidelines:
            GuidelinesSheet(onNext: {
                withAnimation {
                    currentStep = .activation
                }
            })
        case .activation:
            ActivationSheet(onOpenCamera: {
                appState.showPostPaywallOnboarding = false
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.showCameraSheet = true
                }
            }, onBrowseStyles: {
                appState.showPostPaywallOnboarding = false
                dismiss()
            })
        }
    }
}

// MARK: - Sheet 1: Welcome
struct WelcomeSheet: View {
    let onNext: () -> Void
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: 12) {
                Text("Welcome to Eclat ✨")
                    .font(.eclat.displaySmall)
                    .foregroundColor(.white)
                
                // Stacked cards preview (selected styles from onboarding)
                stackedStyleCards
                
                Text("You're all set to preview your perfect look.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Body
            VStack(spacing: 16) {
                Text("You now have full access to Looks.\nPreview styles, experiment freely, and find what truly fits you — before committing.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                
                // CTA
                Button {
                    HapticManager.shared.buttonPress()
                    onNext()
                } label: {
                    Text("Get started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0B0606"))
    }
    
    @State private var currentVisibleCard = 0
    @State private var cardAnimations: [Bool] = [false, false, false]
    
    private var stackedStyleCards: some View {
        ZStack {
            // Animated stacked cards exactly like onboarding
            let styles = ["butterfly-cut", "beach-waves", "90s-blowout"]
            
            ForEach(Array(styles.enumerated()), id: \.offset) { index, imageName in
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // Image with gradient overlay
                        Color(hex: "1C1C1E")
                            .overlay(
                                Image(imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            )
                        
                        // Gradient overlay
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Border
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .frame(width: 150, height: 200)
                .shadow(color: .black.opacity(0.4), radius: 15)
                .offset(y: CGFloat(index) * 5)
                .rotationEffect(.degrees(Double(index - 1) * 4))
                .scaleEffect(cardAnimations[index] ? 1.0 : 0.85)
                .opacity(cardAnimations[index] ? 1.0 : 0.0)
                .zIndex(Double(styles.count - index))
                .animation(
                    .interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.15)
                    .delay(Double(index) * 0.15),
                    value: cardAnimations[index]
                )
            }
        }
        .frame(height: 240)
        .padding(.vertical, 12)
        .onAppear {
            // Trigger animations with haptics
            for index in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                    HapticManager.light()
                    cardAnimations[index] = true
                }
            }
        }
    }
}

// MARK: - Sheet 2: Guidelines
struct GuidelinesSheet: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: 12) {
                Text("For best results")
                    .font(.eclat.displaySmall)
                    .foregroundColor(.white)
                
                Text("Follow these simple guidelines")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Guidelines
            VStack(spacing: 20) {
                GuidelineRow(icon: "face.smiling", title: "Face the camera", subtitle: "Keep your face centered and visible")
                GuidelineRow(icon: "light.max", title: "Good lighting", subtitle: "Natural light works best")
                GuidelineRow(icon: "eye.slash", title: "No hats or hair covering", subtitle: "Let your features show")
                GuidelineRow(icon: "face.dashed", title: "Neutral expression", subtitle: "Relaxed face, no filters")
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Reassurance
            Text("Eclat adapts styles to your facial features for realistic results.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            
            // CTA
            Button {
                HapticManager.shared.buttonPress()
                onNext()
            } label: {
                Text("I'm ready")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0B0606"))
    }
}

// MARK: - Guideline Row
struct GuidelineRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

// MARK: - Sheet 3: Activation
struct ActivationSheet: View {
    let onOpenCamera: () -> Void
    let onBrowseStyles: () -> Void
    
    @EnvironmentObject private var appState: AppState
    
    // All available styles with images and names
    private let availableStyles: [(imageName: String, displayName: String)] = [
        ("90s-blowout", "90s Blowout"),
        ("beach-waves", "Beach Waves"),
        ("butterfly-cut", "Butterfly Cut"),
        ("curtain-bangs", "Curtain Bangs"),
        ("sleek-middle-part", "Sleek Middle Part"),
        ("modern-shag", "Modern Shag")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: 12) {
                Text("Your first Look awaits")
                    .font(.eclat.displaySmall)
                    .foregroundColor(.white)
                
                Text("Start with a style you love")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 40)
            
            // Horizontal scrolling styles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableStyles, id: \.imageName) { style in
                        Button {
                            HapticManager.shared.buttonPress()
                            selectStyleAndOpenCamera(imageName: style.imageName)
                        } label: {
                            ZStack(alignment: .bottom) {
                                // Image
                                Image(style.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 160)
                                    .clipped()
                                
                                // Gradient overlay for text readability
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.7)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                                
                                // Style name
                                Text(style.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.bottom, 8)
                            }
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 180)
            .padding(.vertical, 20)
            
            Spacer()
            
            // Body
            VStack(spacing: 8) {
                Text("Choose a style, take a selfie,\nand preview your look instantly.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                
                Text("Most users find their favorite look within the first minutes.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .italic()
                    .padding(.top, 8)
            }
            
            Spacer()
            
            // CTA
            Button {
                HapticManager.shared.buttonPress()
                onOpenCamera()
            } label: {
                Text("Open Camera")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0B0606"))
    }
    
    private func selectStyleAndOpenCamera(imageName: String) {
        // Find the hairstyle from HairstyleData
        if let hairstyle = HairstyleData.women.first(where: { $0.imageName == imageName }) {
            appState.selectedHairstyle = hairstyle
        }
        
        // Close onboarding and open camera
        appState.showPostPaywallOnboarding = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.showCameraSheet = true
        }
    }
}

#Preview {
    PostPaywallOnboarding()
        .environmentObject(AppState())
}
