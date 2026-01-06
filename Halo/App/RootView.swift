//
//  RootView.swift
//  Halo
//
//  Root navigation controller - manages app flow based on state
//

import SwiftUI

struct RootView: View {
    
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Each child view has its own AnimatedDarkGradient
            
            // Content based on app state
            Group {
                switch appState.currentScreen {
                case .splash:
                    SplashView()
                        .transition(.opacity)
                        .task {
                            await appState.performBootSequence()
                        }
                    
                case .onboarding:
                    OnboardingView()
                        .transition(.opacity)
                    
                case .processing:
                    ProcessingView()
                        .transition(.opacity)
                    
                case .result:
                    ResultView()
                        .transition(.push(from: .trailing))
                    
                case .paywall:
                    PaywallView()
                        .transition(.move(edge: .bottom))
                    
                case .auth:
                    AuthView()
                        .transition(.opacity)
                    
                case .home:
                    HomeView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState.currentScreen)
        }
        .sheet(isPresented: $appState.showCameraSheet) {
            CameraView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $appState.showHistorySheet) {
            HistoryView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager())
}

// MARK: - Splash View
struct SplashView: View {
    @State private var opacity = 0.0
    @State private var scale = 0.8
    
    var body: some View {
        ZStack {
            // Background
            AnimatedDarkGradient()
            
            // Logo
            Text("Halo")
                .font(.custom("Agrandir-NarrowBold", size: 64))
                .foregroundColor(.white)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                opacity = 1.0
                scale = 1.0
            }
        }
    }
}
