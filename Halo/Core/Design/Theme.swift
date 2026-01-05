//
//  Theme.swift
//  Halo
//
//  Design System - iOS 26 Liquid Glass Compatible
//

import SwiftUI

// MARK: - Theme Colors
extension Color {
    static let theme = ThemeColors()
}

struct ThemeColors {
    // Background - Optimized for Liquid Glass layering
    let backgroundTop = Color(hex: "060303")       // Top of gradient
    let backgroundBottom = Color(hex: "1B1526")    // Bottom of gradient
    let backgroundPrimary = Color(hex: "0D0A10")   // Midpoint for flat bg
    let backgroundSecondary = Color(hex: "12101A")
    let backgroundTertiary = Color(hex: "1A1620")
    let backgroundCard = Color(hex: "1E1A24")
    
    // Accent - Vibrant colors for glass tinting
    let accentPrimary = Color(hex: "A855F7")       // Purple
    let accentSecondary = Color(hex: "EC4899")     // Pink
    let accentTertiary = Color(hex: "818CF8")      // Indigo
    
    // Text - High contrast for glass backgrounds
    let textPrimary = Color.white
    let textSecondary = Color(hex: "9CA3AF")
    let textTertiary = Color(hex: "6B7280")
    
    // Semantic
    let success = Color(hex: "34D399")
    let warning = Color(hex: "FBBF24")
    let error = Color(hex: "F87171")
    
    // Blur overlay
    let blurOverlay = Color.black.opacity(0.3)
    
    // Glass - Optimized for iOS 26 Liquid Glass
    let glassFill = Color.white.opacity(0.03)
    let glassBorder = Color.white.opacity(0.06)
    let glassHighlight = Color.white.opacity(0.1)
}

// MARK: - Gradient Presets
extension LinearGradient {
    // Main app background gradient - optimized for glass layering
    static let haloBackground = LinearGradient(
        colors: [Color.theme.backgroundTop, Color.theme.backgroundBottom],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let haloDeep = LinearGradient(
        colors: [Color(hex: "030102"), Color(hex: "0F0A14")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let haloPrimary = LinearGradient(
        colors: [Color.theme.accentPrimary, Color.theme.accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let haloSecondary = LinearGradient(
        colors: [Color.theme.accentSecondary, Color.theme.accentTertiary],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let haloSubtle = LinearGradient(
        colors: [Color.theme.accentPrimary.opacity(0.15), Color.theme.accentSecondary.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Mesh-like gradient for hero backgrounds
    static let haloMesh = LinearGradient(
        colors: [
            Color.theme.accentPrimary.opacity(0.2),
            Color.theme.backgroundPrimary,
            Color.theme.accentSecondary.opacity(0.15)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Radial Gradients for Glass Effects
extension RadialGradient {
    static let haloGlow = RadialGradient(
        colors: [
            Color.theme.accentPrimary.opacity(0.3),
            Color.theme.accentPrimary.opacity(0.1),
            Color.clear
        ],
        center: .center,
        startRadius: 0,
        endRadius: 200
    )
}

// MARK: - Typography (System Default - Optimized for Glass)
extension Font {
    static let halo = HaloTypography()
}

struct HaloTypography {
    // Display - Bold for glass contrast
    let displayLarge = Font.custom("Agrandir-NarrowBold", size: 40)
    let displayMedium = Font.custom("Agrandir-NarrowBold", size: 32)
    let displaySmall = Font.custom("Agrandir-NarrowBold", size: 28)
    
    // Headlines
    let headlineLarge = Font.system(size: 24, weight: .semibold, design: .default)
    let headlineMedium = Font.system(size: 20, weight: .semibold, design: .default)
    let headlineSmall = Font.system(size: 18, weight: .medium, design: .default)
    
    // Body
    let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    // Labels
    let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
    let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
    let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
    
    // Caption
    let caption = Font.system(size: 12, weight: .regular, design: .default)
}

// MARK: - Spacing
enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius (iOS 26 Optimized)
enum CornerRadius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let full: CGFloat = 9999
}

// MARK: - Glass Effect Helpers
extension View {
    /// Apply a subtle inner glow effect for depth
    func innerGlow(color: Color = Color.theme.accentPrimary, radius: CGFloat = 20) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(color.opacity(0.15), lineWidth: 1)
                .blur(radius: 2)
        )
    }
    
    /// Apply a floating effect with subtle shadow
    func floating(y: CGFloat = -2) -> some View {
        self
            .offset(y: y)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
#Preview("Theme Colors") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            // Background colors
            Group {
                Text("Backgrounds")
                    .font(.headline)
                HStack {
                    ColorSwatch(color: Color.theme.backgroundTop, label: "Top")
                    ColorSwatch(color: Color.theme.backgroundBottom, label: "Bottom")
                    ColorSwatch(color: Color.theme.backgroundPrimary, label: "Primary")
                }
            }
            
            // Accent colors
            Group {
                Text("Accents")
                    .font(.headline)
                HStack {
                    ColorSwatch(color: Color.theme.accentPrimary, label: "Primary")
                    ColorSwatch(color: Color.theme.accentSecondary, label: "Secondary")
                    ColorSwatch(color: Color.theme.accentTertiary, label: "Tertiary")
                }
            }
            
            // Semantic colors
            Group {
                Text("Semantic")
                    .font(.headline)
                HStack {
                    ColorSwatch(color: Color.theme.success, label: "Success")
                    ColorSwatch(color: Color.theme.warning, label: "Warning")
                    ColorSwatch(color: Color.theme.error, label: "Error")
                }
            }
        }
        .padding()
    }
    .background(LinearGradient.haloBackground)
}

struct ColorSwatch: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(color)
                .frame(width: 60, height: 60)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
