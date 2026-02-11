//
//  DailyLimitReachedView.swift
//  Eclat
//
//  Mini sheet shown when user reaches daily generation limit
//  Design: Simple, elegant, no stress - they're already paying!
//

import SwiftUI

struct DailyLimitReachedView: View {
    
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
            
            // Emoji & Visual
            Text("✨")
                .font(.system(size: 56))
                .padding(.top, 8)
            
            // Main Message
            VStack(spacing: 8) {
                Text("You're out of looks")
                    .font(.eclat.displayMedium)
                    .foregroundColor(.white)
                
                Text("Your looks refresh tomorrow")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .multilineTextAlignment(.center)
            
            // Subtle encouragement
            Text("We cap daily looks to keep quality high.\nCome back tomorrow for more magic.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer().frame(height: 8)
            
            // Single CTA - Close gracefully
            Button {
                HapticManager.shared.buttonPress()
                dismiss()
                appState.navigateTo(.home)
            } label: {
                Text("Got it")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white, in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0B0606"))
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
    }
}

#Preview {
    DailyLimitReachedView()
        .environmentObject(AppState())
}
