//
//  CreatorModeSection.swift
//  Eclat
//
//  Minimalist Creator Mode Section - Exclusive for Weekly Subscribers
//

import SwiftUI

// MARK: - Creator Mode Section
struct CreatorModeSection: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    
    let onSubscribe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header
            sectionHeader
            
            if subscriptionManager.isSubscribed {
                // For Subscribers: Clean, elegant access
                subscriberView
            } else {
                // For Non-Subscribers: Strong CTA
                nonSubscriberView
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
    }
    
    // MARK: - Section Header
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Creator Mode")
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(.white)
                
                // Subtle badge
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            
            Text("Unlimited creativity, no boundaries")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Subscriber View (Clean Access)
    private var subscriberView: some View {
        VStack(spacing: 16) {
            // Feature Grid
            VStack(spacing: 12) {
                creatorFeatureRow(
                    icon: "infinity",
                    title: "Unlimited Looks",
                    description: "Generate as many styles as you want"
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                creatorFeatureRow(
                    icon: "wand.and.stars",
                    title: "Priority Processing",
                    description: "Your generations process first"
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                creatorFeatureRow(
                    icon: "arrow.down.circle",
                    title: "HD Downloads",
                    description: "Export in highest quality"
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                creatorFeatureRow(
                    icon: "sparkles",
                    title: "Early Access",
                    description: "Try new features before everyone"
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 16, height: 16)
                            .blur(radius: 4)
                    )
                
                Text("Creator Mode Active")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Non-Subscriber View (Strong CTA)
    private var nonSubscriberView: some View {
        VStack(spacing: 20) {
            // Hero Image/Visual (Optional - you can add a visual asset here)
            creatorModeHeroVisual
            
            // Features List
            VStack(spacing: 16) {
                ctaFeatureRow(
                    icon: "infinity",
                    title: "Unlimited Looks",
                    gradient: [Color.purple, Color.pink]
                )
                
                ctaFeatureRow(
                    icon: "wand.and.stars",
                    title: "Priority Processing",
                    gradient: [Color.blue, Color.cyan]
                )
                
                ctaFeatureRow(
                    icon: "arrow.down.circle",
                    title: "HD Downloads",
                    gradient: [Color.orange, Color.yellow]
                )
                
                ctaFeatureRow(
                    icon: "sparkles",
                    title: "Early Access to Features",
                    gradient: [Color.pink, Color.purple]
                )
            }
            
            // CTA Button
            Button {
                HapticManager.shared.buttonPress()
                onSubscribe()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Unlock Creator Mode")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: "8B5CF6"),
                            Color(hex: "EC4899")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color(hex: "8B5CF6").opacity(0.4), radius: 20, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Pricing Info
            Text("From $4.99/week • Cancel anytime")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Hero Visual (Minimalist)
    private var creatorModeHeroVisual: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "8B5CF6").opacity(0.2),
                            Color(hex: "EC4899").opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
            
            // Centered icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 10)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
    
    // MARK: - Feature Row (Subscriber)
    private func creatorFeatureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
    }
    
    // MARK: - CTA Feature Row (Non-Subscriber)
    private func ctaFeatureRow(icon: String, title: String, gradient: [Color]) -> some View {
        HStack(spacing: 12) {
            // Gradient icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.2) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.green)
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(hex: "0B0606").ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 40) {
                // Subscriber version
                CreatorModeSection {
                    print("Subscribe tapped")
                }
                .environmentObject({
                    let manager = SubscriptionManager.shared
                    // Simulate subscribed state in preview if possible
                    return manager
                }())
                .environmentObject(AppState())
                
                // Non-subscriber version
                CreatorModeSection {
                    print("Subscribe tapped")
                }
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(AppState())
            }
            .padding(.vertical, 40)
        }
    }
    .preferredColorScheme(.dark)
}
