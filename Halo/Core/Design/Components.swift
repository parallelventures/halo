//
//  Components.swift
//  Halo
//
//  Reusable UI Components - iOS 26 Native Style
//

import SwiftUI

// MARK: - Glass Effect Compatibility (iOS 26+ only for buttons)
extension View {
    /// Applies glass effect on iOS 26+ buttons only
    @ViewBuilder
    func glassButton(in shape: some InsettableShape = Capsule()) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self
        }
    }
}

// MARK: - Primary CTA Button
// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    HapticManager.shared.buttonPress()
                } else {
                    HapticManager.shared.buttonRelease()
                }
            }
    }
}

// MARK: - Primary CTA Button
struct HaloCTAButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.white, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Secondary Button
struct HaloSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .frame(height: 44)
            .padding(.horizontal, Spacing.sm)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(Color.theme.textPrimary)
    }
}

// MARK: - Icon Button
struct HaloIconButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    init(
        icon: String,
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(size > 44 ? .large : .regular)
        .tint(Color.theme.textPrimary)
    }
}

// MARK: - Glass Card (Material Background)
struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    
    init(padding: CGFloat = Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
    }
}

// MARK: - Hairstyle Card
struct HairstyleCard: View {
    let hairstyle: HairstyleOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "scissors")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.theme.accentPrimary : .secondary)
                    .frame(width: 80, height: 80)
                    .background(
                        isSelected ? Color.theme.accentPrimary.opacity(0.1) : Color.theme.glassFill,
                        in: RoundedRectangle(cornerRadius: CornerRadius.md)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .strokeBorder(isSelected ? Color.theme.accentPrimary : Color.theme.glassBorder, lineWidth: 1)
                    )
                
                Text(hairstyle.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.theme.accentPrimary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pricing Card
struct PricingCard: View {
    let title: String
    let price: String
    let period: String
    let features: [String]
    let isPopular: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.medium()
            action()
        }) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                            Text(price)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
                            Text("/ \(period)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isPopular {
                        Text("BEST VALUE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.theme.accentPrimary, in: Capsule())
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.theme.accentPrimary)
                            
                            Text(feature)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .strokeBorder(isSelected ? Color.theme.accentPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Indicator
struct HaloProgress: View {
    let progress: Double
    
    var body: some View {
        ProgressView(value: progress)
            .tint(Color.theme.accentPrimary)
    }
}

// MARK: - Bottom CTA Container
struct BottomCTAContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(.bar)
                    .ignoresSafeArea(edges: .bottom)
            )
    }
}

// MARK: - Chip/Tag
struct HaloChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    
    init(_ label: String, icon: String? = nil, isSelected: Bool = false) {
        self.label = label
        self.icon = icon
        self.isSelected = isSelected
    }
    
    var body: some View {
        HStack(spacing: Spacing.xxs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(isSelected ? Color.theme.accentPrimary : .secondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            isSelected ? Color.theme.accentPrimary.opacity(0.1) : Color.theme.glassFill,
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.theme.accentPrimary.opacity(0.3) : Color.theme.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Previews
#Preview("Buttons") {
    VStack(spacing: 20) {
        HaloCTAButton("Continue", icon: "arrow.right") {}
        HaloCTAButton("Loading...", isLoading: true) {}
        HaloSecondaryButton("Skip", icon: "xmark") {}
        
        HStack {
            HaloIconButton(icon: "xmark") {}
            HaloIconButton(icon: "camera") {}
            HaloIconButton(icon: "photo") {}
        }
        
        HStack {
            HaloChip("Popular", icon: "flame.fill", isSelected: true)
            HaloChip("New", icon: "sparkles")
            HaloChip("Trending")
        }
    }
    .padding()
    .background(LinearGradient.haloBackground)
}

#Preview("Cards") {
    ScrollView {
        VStack(spacing: 20) {
            GlassCard {
                Text("Glass Card Content")
                    .foregroundColor(.white)
            }
            
            PricingCard(
                title: "Annual",
                price: "$69.99",
                period: "year",
                features: ["Unlimited try-ons", "HD exports", "Priority support"],
                isPopular: true,
                isSelected: true
            ) {}
        }
        .padding()
    }
    .background(LinearGradient.haloBackground)
}
