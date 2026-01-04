//
//  HomeView.swift
//  Halo
//
//  Premium home screen - redesigned
//

import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    var body: some View {
        ZStack {
            // Aurora background
            AnimatedDarkGradient()
            
            // Main content
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    
                    // MARK: - Header
                    HStack {
                        Text("Halo")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // History
                        Button {
                            HapticManager.shared.buttonPress()
                            appState.navigateTo(.history)
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 40, height: 40)
                        }
                        .glassCircleStyle()
                        
                        // Pro badge or upgrade
                        if subscriptionManager.isSubscribed {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 11))
                                Text("PRO")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassChipStyle()
                        } else {
                            Button {
                                HapticManager.shared.buttonPress()
                                appState.navigateTo(.paywall)
                            } label: {
                                Text("Upgrade")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                            }
                            .glassChipStyle()
                        }
                    }
                    .padding(.top, Spacing.md)
                    
                    // MARK: - Hero Card
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text("AI Hairstyle Try-On")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("See yourself with new looks instantly")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .glassCardStyle()
                    
                    // MARK: - Quick Actions
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("QUICK START")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1)
                        
                        HStack(spacing: Spacing.sm) {
                            // Take Selfie
                            Button {
                                HapticManager.shared.buttonPress()
                                appState.showCameraSheet = true
                            } label: {
                                VStack(spacing: Spacing.sm) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    
                                    Text("Take Selfie")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                            }
                            .glassCardStyle(cornerRadius: 16)
                            
                            // From Gallery
                            Button {
                                HapticManager.shared.buttonPress()
                                appState.showCameraSheet = true
                            } label: {
                                VStack(spacing: Spacing.sm) {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    
                                    Text("From Gallery")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                            }
                            .glassCardStyle(cornerRadius: 16)
                        }
                    }
                    
                    // MARK: - Recent (if available)
                    if let image = appState.generatedImage {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("RECENT")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(1)
                            
                            Button {
                                HapticManager.shared.buttonPress()
                                appState.navigateTo(.result)
                            } label: {
                                HStack(spacing: Spacing.md) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .blur(radius: subscriptionManager.isSubscribed ? 0 : 6)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(appState.selectedHairstyle?.name ?? "Your Look")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Text("Tap to view")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(Spacing.md)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 120)
            }
            
            // MARK: - Bottom CTA
            VStack {
                Spacer()
                
                Button {
                    HapticManager.shared.buttonPress()
                    appState.showCameraSheet = true
                } label: {
                    Text("Try New Look")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .glassCTAStyle()
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }
        }
    }
}

// MARK: - Glass Style Extensions
extension View {
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
