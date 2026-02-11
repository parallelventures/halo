//
//  OutOfLooksSheet.swift
//  Eclat
//
//  "Out of looks" mini sheet - Soft, informative, non-aggressive
//

import SwiftUI

struct OutOfLooksSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    // Sample styles for the visual stack (passed in or use defaults)
    var previewStyles: [StylePreference] = Array(StylePreference.womenStyles.prefix(3))
    
    var body: some View {
        VStack(spacing: 24) {
            
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
            
            Spacer().frame(height: 8)
            
            // MARK: - Visual Stack (Blurred cards)
            visualStack
            
            // MARK: - Title
            Text("You're out of looks")
                .font(.eclat.displaySmall)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // MARK: - Subtitle (Rationalization)
            Text("Each look is generated uniquely for you.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Spacer().frame(height: 8)
            
            // MARK: - Primary CTA
            Button {
                dismiss()
                // Always show paywall - Free users need Creator or Atelier to generate
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.showPaywall()
                }
            } label: {
                Text("Get more looks")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white, in: Capsule())
            }
            .padding(.horizontal, 24)
            
            // MARK: - Secondary Option (Ghost)
            Button {
                dismiss()
            } label: {
                Text("Maybe later")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color(hex: "0B0606"))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .interactiveDismissDisabled(false) // Allow swipe down
    }
    
    // MARK: - Visual Stack
    private var visualStack: some View {
        ZStack {
            ForEach(Array(previewStyles.enumerated()), id: \.offset) { index, style in
                previewCard(for: style, at: index)
            }
        }
        .frame(height: 160)
    }
    
    // MARK: - Preview Card Helper
    @ViewBuilder
    private func previewCard(for style: StylePreference, at index: Int) -> some View {
        let scale = 1.0 - CGFloat(index) * 0.04
        let xOffset = CGFloat(index - 1) * 30
        let rotation = Double(index - 1) * 5
        let opacity = 1.0 - Double(index) * 0.15
        
        Group {
            if let imageName = style.image {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient.eclatPrimary)
            }
        }
        .frame(width: 100, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .blur(radius: 2)
        .scaleEffect(scale)
        .offset(x: xOffset)
        .rotationEffect(.degrees(rotation))
        .opacity(opacity)
    }
}

#Preview {
    OutOfLooksSheet()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}
