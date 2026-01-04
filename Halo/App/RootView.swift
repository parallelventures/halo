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
                case .onboarding:
                    OnboardingView()
                        .transition(.opacity)
                    
                case .camera:
                    // Camera is now presented as a sheet
                    HomeView()
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
                    
                case .home:
                    HomeView()
                        .transition(.opacity)
                    
                case .history:
                    HistoryView()
                        .transition(.push(from: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState.currentScreen)
        }
        .sheet(isPresented: $appState.showCameraSheet) {
            CameraView()
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
