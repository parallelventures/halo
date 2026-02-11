//
//  DevHairstyleSheet.swift
//  Eclat
//
//  Created for internal dev use.
//

import SwiftUI

struct DevHairstyleSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    private let months = Calendar.current.monthSymbols
    
    // Map 12 months to styles (cycling if needed)
    private var styles: [StylePreference] {
        let all = StylePreference.womenStyles
        guard !all.isEmpty else { return [] }
        // Create 12 items for 12 months (or however many we have loop)
        return (0..<12).map { i in all[i % all.count] }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Elegant Title (Matching Home Page)
            Text("Eclat")
                .font(.eclat.displaySmall) // Matches Home header
                .foregroundColor(.white)
                .padding(.top, 20)
                .padding(.bottom, 10)
            
            // Minimalist TabView Pager
            TabView {
                ForEach(0..<months.count, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Month Label (Custom Serif Font)
                        Text(months[index])
                            .font(.custom("InstrumentSerif-Regular", size: 32))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // The Single Hairstyle Card
                        if index < styles.count {
                            BigStyleCard(style: styles[index]) {
                                // Action
                            }
                            .padding(.horizontal, 32) // Increased padding to reduce size slightly
                        }
                        
                        Spacer()
                        Spacer() // Visual balance
                    }
                    .tag(index)
                    .containerShape(Rectangle())
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            
            // Bottom CTA
            GlassCapsuleButton(
                title: "See this version of you",
                systemImage: "sparkles",
                shimmer: true
            ) {
                // Action: Select style and go to camera
                if let index = styles.indices.first, index < styles.count {
                    // For now, just close or navigate.
                    // Ideally: Select this specific style
                }
                HapticManager.shared.buttonPress()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34) // Safe area spacing
        }
        .background(Color(hex: "0B0606").ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}

// Local larger card component
struct BigStyleCard: View {
    let style: StylePreference
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // 1. Define the container shape and ratio explicitly
            Color.clear
                .aspectRatio(4/5, contentMode: .fit)
                .background(
                    // 2. Fill it with the image
                    GeometryReader { geo in
                        if let imageName = style.image {
                            Image(imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        } else {
                            Color.gray.opacity(0.2)
                                .overlay(Image(systemName: "photo").foregroundColor(.white))
                        }
                    }
                )
                .overlay(
                    // 3. Text & Gradient Overlay
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        
                        Text(style.name)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.bottom, 24)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
