//
//  AuroraButton.swift
//  Eclat
//
//  Premium Aurora Breathing CTA Button - Senior Level UI/UX
//

import SwiftUI

// MARK: - Aurora Breathing Layer
/// Un arc/aurora animé qui respire en bas du bouton avec couleurs Apple Intelligence
struct AuroraBreathingLayer: View {
    var c1: Color = Color.theme.accentPrimary
    var c2: Color = Color.theme.accentTertiary
    var c3: Color = Color.theme.accentSecondary
    var period: Double = 6.0          // secondes / cycle
    var intensity: CGFloat = 1.0      // 0.0–1.5 (amplitude)
    
    // Palette "Astral Bloom" - Couleurs douces qui tournent fluidement
    private func getSoftColors(at time: Double) -> [Color] {
        let rotationSpeed = 0.15
        let colorPhase = time * rotationSpeed
        
        let baseColors: [Color] = [
            Color(hex: "A9B8FF"), // Veil Periwinkle
            Color(hex: "E1D2FF"), // Orchid Haze
            Color(hex: "CDE1F6"), // Glacier Wash
            Color(hex: "BFE6D7"), // Dew Mint
            Color(hex: "CFE2C4"), // Lichen Sage
            Color(hex: "FFC7A6"), // Peach Dawn
            Color(hex: "F7C2D2"), // Rose Mallow
            Color(hex: "F2E7B6"), // Pollen Crème
            Color(hex: "E7F1FF")  // Moon Opal
        ]
        
        var rotatedColors: [Color] = []
        let numColors = baseColors.count
        
        for i in 0..<6 {
            let exactIndex = (colorPhase + Double(i))
            let baseIndex = Int(exactIndex) % numColors
            let nextIndex = (baseIndex + 1) % numColors
            let blend = exactIndex.truncatingRemainder(dividingBy: 1.0)
            
            let color = interpolateColor(from: baseColors[baseIndex], to: baseColors[nextIndex], progress: blend)
            rotatedColors.append(color)
        }
        
        return rotatedColors
    }
    
    private func interpolateColor(from: Color, to: Color, progress: Double) -> Color {
        let p = CGFloat(progress)
        let uiFrom = UIColor(from)
        let uiTo = UIColor(to)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiFrom.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiTo.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return Color(
            red: Double((1 - p) * r1 + p * r2),
            green: Double((1 - p) * g1 + p * g2),
            blue: Double((1 - p) * b1 + p * b2)
        )
    }
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let ω = 2 * Double.pi / period
            let phase = reduceMotion ? 0 : t * ω
            let s = 0.5 + 0.5 * sin(phase)

            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let centerX = w / 2
                let softColors = getSoftColors(at: t)
                
                func drawBreathingArcPoint(radius: CGFloat, colorIndex: Int, opacity: CGFloat, blurRadius: CGFloat) {
                    let pointY = h * 0.55
                    let arcRadius = radius * (1.4 + 0.08 * s)
                    var arcPath = Path()
                    let arcCenterY = pointY + arcRadius * 0.2
                    let arcWidth = arcRadius * 1.0
                    let arcHeight = arcRadius * 2.2
                    let startPoint = CGPoint(x: centerX - arcWidth, y: arcCenterY)
                    let endPoint = CGPoint(x: centerX + arcWidth, y: arcCenterY)
                    
                    arcPath.move(to: startPoint)
                    arcPath.addQuadCurve(
                        to: CGPoint(x: centerX, y: arcCenterY + arcHeight * 0.3),
                        control: CGPoint(x: centerX - arcWidth * 0.6, y: arcCenterY + arcHeight * 0.6)
                    )
                    arcPath.addQuadCurve(
                        to: endPoint,
                        control: CGPoint(x: centerX + arcWidth * 0.6, y: arcCenterY + arcHeight * 0.6)
                    )
                    arcPath.addLine(to: startPoint)
                    arcPath.closeSubpath()
                    
                    let gradientColors = [
                        softColors[colorIndex % softColors.count],
                        softColors[(colorIndex + 1) % softColors.count],
                        softColors[(colorIndex + 2) % softColors.count]
                    ]
                    let gradient = Gradient(colors: gradientColors)
                    
                    ctx.addFilter(.blur(radius: blurRadius))
                    ctx.opacity = opacity * 0.45
                    ctx.fill(arcPath, with: .radialGradient(
                        gradient,
                        center: CGPoint(x: centerX, y: arcCenterY),
                        startRadius: 0,
                        endRadius: arcRadius
                    ))
                }
                
                func drawAccentPoints(phase: Double) {
                    let numPoints = 3
                    let orbitRadius = w * 0.15
                    
                    for i in 0..<numPoints {
                        let angle = phase + Double(i) * 2.0 * .pi / Double(numPoints)
                        let x = centerX + cos(angle) * orbitRadius * (0.8 + 0.3 * s)
                        let y = h * 0.75 + sin(angle) * orbitRadius * 0.5 * (0.8 + 0.3 * s)
                        let pointRadius = 8 + 4 * s
                        
                        var pointPath = Path()
                        pointPath.addEllipse(in: CGRect(
                            x: x - pointRadius/2,
                            y: y - pointRadius/2,
                            width: pointRadius,
                            height: pointRadius
                        ))
                        
                        let pointColor = softColors[i % softColors.count]
                        ctx.addFilter(.blur(radius: 10))
                        ctx.opacity = 0.25 * (0.5 + 0.15 * s)
                        ctx.fill(pointPath, with: .color(pointColor))
                    }
                }
                
                let baseRadius = min(w, h) * 2.2
                let baseOpacity = 0.25 + 0.15 * s
                ctx.blendMode = .screen
                
                ctx.opacity = baseOpacity * 0.3
                drawBreathingArcPoint(radius: baseRadius * 1.0, colorIndex: 0, opacity: 1.0, blurRadius: 24 + 12 * s)
                
                ctx.opacity = baseOpacity * 0.25
                drawBreathingArcPoint(radius: baseRadius * 0.8, colorIndex: 2, opacity: 1.0, blurRadius: 20 + 10 * s)
                
                ctx.opacity = baseOpacity * 0.15
                drawBreathingArcPoint(radius: baseRadius * 0.6, colorIndex: 4, opacity: 1.0, blurRadius: 16 + 8 * s)
                
                drawAccentPoints(phase: phase * 0.5)
            }
        }
    }
}

// MARK: - Glass Capsule Button
/// Le bouton "capsule glass" avec aurora breathing
struct GlassCapsuleButton: View {
    var title: String
    var systemImage: String = "sparkles"
    var c1: Color = Color.theme.accentPrimary
    var c2: Color = Color.theme.accentTertiary
    var c3: Color = Color.theme.accentSecondary
    var period: Double = 6
    var intensity: CGFloat = 1.0
    var shimmer: Bool = false
    var isLoading: Bool = false
    var action: () -> Void

    @State private var shimmerPhase: CGFloat = -0.5

    var body: some View {
        Button(action: action) {
            ZStack {
                // Aurora breathing - strictly clipped
                AuroraBreathingLayer(c1: c1, c2: c2, c3: c3, period: period, intensity: intensity)
                    .allowsHitTesting(false)
                    .blendMode(.screen)
                    .opacity(0.85)
                    .mask(Capsule()) // Strict mask to prevent blur overflow

                // Content
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: 10) {
                        if !systemImage.isEmpty {
                            Image(systemName: systemImage)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                }
                
                // Shimmer Overlay (Vif + Blur + Smooth)
                if shimmer {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.0),
                                        .init(color: .white.opacity(0.1), location: 0.3),
                                        .init(color: .white.opacity(0.6), location: 0.5), // Vif center
                                        .init(color: .white.opacity(0.1), location: 0.7),
                                        .init(color: .clear, location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 1.5) // Large gradient
                            .blur(radius: 12) // Smooth blur
                            .offset(x: -geo.size.width + (shimmerPhase * (geo.size.width * 3)))
                            .blendMode(.overlay)
                            .mask(Capsule())
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.clear)
            .clipShape(Capsule())
            .modifier(GlassEffectModifier())
            .contentShape(Capsule())
        }
        .buttonStyle(AuroraButtonStyle())
        .onAppear {
            if shimmer {
                // Smooth repeating animation
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            }
        }
    }
}

// MARK: - Glass Effect Modifier (iOS Version Fallback)
struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Button Style
struct AuroraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .blur(radius: configuration.isPressed ? 0.5 : 0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    // Press haptic
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                } else {
                    // Release haptic
                    let impactSoft = UIImpactFeedbackGenerator(style: .soft)
                    impactSoft.impactOccurred()
                }
            }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(hex: "0B0606").ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassCapsuleButton(title: "Try New Look", systemImage: "sparkles") {
                print("Tapped")
            }
            .padding(.horizontal, 20)
        }
    }
}
