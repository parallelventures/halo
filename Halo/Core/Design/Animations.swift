//
//  Animations.swift
//  Halo
//
//  Subtle, refined animations
//

import SwiftUI

// MARK: - Animation Presets
extension Animation {
    
    // MARK: - Subtle animations for UI
    
    /// Default smooth animation
    static let haloSmooth = Animation.easeOut(duration: 0.25)
    
    /// Quick interaction feedback
    static let haloQuick = Animation.easeOut(duration: 0.15)
    
    /// Page transitions
    static let haloSlow = Animation.easeInOut(duration: 0.35)
    
    /// Spring for selections
    static let haloSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    
    /// Bouncy but controlled
    static let haloBouncy = Animation.spring(response: 0.4, dampingFraction: 0.7)
    
    // MARK: - Delayed versions
    
    static func haloSmooth(delay: Double) -> Animation {
        Animation.easeOut(duration: 0.25).delay(delay)
    }
    
    static func haloQuick(delay: Double) -> Animation {
        Animation.easeOut(duration: 0.15).delay(delay)
    }
    
    static func haloSpring(delay: Double) -> Animation {
        Animation.spring(response: 0.35, dampingFraction: 0.8).delay(delay)
    }
    
    static func haloBouncy(delay: Double) -> Animation {
        Animation.spring(response: 0.4, dampingFraction: 0.7).delay(delay)
    }
    
    // MARK: - Legacy support
    static let haloEaseOut = Animation.easeOut(duration: 0.25)
    static let haloSnappy = Animation.easeOut(duration: 0.2)
    
    static func haloEaseOut(delay: Double) -> Animation {
        Animation.easeOut(duration: 0.25).delay(delay)
    }
}

// MARK: - Transitions
extension AnyTransition {
    static let haloFade = AnyTransition.opacity
    static let haloScale = AnyTransition.scale(scale: 0.98).combined(with: .opacity)
    static let slideUp = AnyTransition.move(edge: .bottom).combined(with: .opacity)
}

// MARK: - Haptics (Core Haptics)
import CoreHaptics

final class HapticManager {
    
    static let shared = HapticManager()
    
    private var engine: CHHapticEngine?
    
    private init() {
        prepareEngine()
    }
    
    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            try engine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }
    
    private func restartIfNeeded() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            try engine?.start()
        } catch {
            prepareEngine()
        }
    }
    
    // MARK: - Button Press (touch down)
    func buttonPress() {
        restartIfNeeded()
        
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [sharpness, intensity],
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Fallback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    // MARK: - Button Release (touch up)
    func buttonRelease() {
        restartIfNeeded()
        
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [sharpness, intensity],
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Fallback
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
    
    // MARK: - Legacy static methods
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    static func light() { impact(.light) }
    static func medium() { impact(.medium) }
    static func heavy() { impact(.heavy) }
    static func success() { notification(.success) }
    static func warning() { notification(.warning) }
    static func error() { notification(.error) }
}

// MARK: - Color Hex Extension (Int format)
extension Color {
    init(hex: UInt64) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

// MARK: - Aurora Breathing Background (arc du bas)

struct AnimatedDarkGradient: View {
    // Palette "Astral Bloom" enrichie - Cœurs chromatiques (pastels profonds + bleu/violet)
    private let darkAuroraColors: [Color] = [
        Color(hex: 0xCDE1F6).opacity(0.85), // Glacier Wash (bleu glacier)
        Color(hex: 0xA9D6F7).opacity(0.85), // Light Sky Blue
        Color(hex: 0x7FD3E0).opacity(0.85), // Aqua Breeze
        Color(hex: 0x4EB0B3).opacity(0.85), // Turquoise
        Color(hex: 0x3A9B9E).opacity(0.85), // Teal medium
        Color(hex: 0x2A8F8D).opacity(0.85), // Teal deep
        Color(hex: 0xBFE6D7).opacity(0.8),  // Dew Mint (menthe)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond gris foncé (moins sombre que noir pur)
                Color(hex: 0x0A0A0F)
                    .ignoresSafeArea()
                
                // Arc aurora - gradient radial positionné sous l'écran
                TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = (sin(time * 0.1) + 1) / 2
                    // Breathing motion (subtle pulsing)
                    let breath = (sin(time * 0.6) + 1) / 2
                    
                    // Interpolation entre les couleurs
                    let colorIndex = Int(phase * Double(darkAuroraColors.count - 1))
                    let nextColorIndex = (colorIndex + 1) % darkAuroraColors.count
                    let blend = (phase * Double(darkAuroraColors.count - 1)).truncatingRemainder(dividingBy: 1.0)
                    
                    let currentColor = interpolateColor(
                        from: darkAuroraColors[colorIndex],
                        to: darkAuroraColors[nextColorIndex],
                        progress: blend
                    )
                    
                    // Arc principal - gradient radial centré sous l'écran
                    RadialGradient(
                        colors: [
                            currentColor,
                            currentColor.opacity(0.45),
                            currentColor.opacity(0.28),
                            currentColor.opacity(0.16),
                            currentColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .init(x: 0.5, y: 1.0), // Centré en bas
                        startRadius: 0,
                        endRadius: geometry.size.height * (0.46 + 0.10 * breath) // Breathing radius (slightly larger)
                    )
                    .offset(y: geometry.size.height * (0.10 + 0.035 * breath)) // Slightly higher + motion
                    .blur(radius: 34 + 16 * breath)
                    .opacity(0.48 + 0.18 * breath) // More visible but still subtle
                    .blendMode(.screen) // Blend mode pour superposition douce
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // Interpolation de couleur fluide
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
            blue: Double((1 - p) * b1 + p * b2),
            opacity: Double((1 - p) * a1 + p * a2)
        )
    }
}

// MARK: - Animated Green Gradient (pour WelcomeGiftScreen)

struct AnimatedGreenGradient: View {
    // Palette verte de l'app avec bleu/violet subtil
    private let greenAuroraColors: [Color] = [
        Color(hex: 0xCDE1F6).opacity(0.85), // Glacier Wash (bleu glacier)
        Color(hex: 0xA9D6F7).opacity(0.85), // Light Sky Blue
        Color(hex: 0x7FD3E0).opacity(0.85), // Aqua Breeze
        Color(hex: 0x4EB0B3).opacity(0.85), // Turquoise
        Color(hex: 0x3A9B9E).opacity(0.85), // Teal medium
        Color(hex: 0x2A8F8D).opacity(0.85), // Teal deep
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond noir pur
                Color.black
                    .ignoresSafeArea()
                
                // Arc aurora - gradient radial positionné sous l'écran
                TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = (sin(time * 0.1) + 1) / 2
                    // Breathing motion (subtle pulsing)
                    let breath = (sin(time * 0.6) + 1) / 2
                    
                    // Interpolation entre les couleurs
                    let colorIndex = Int(phase * Double(greenAuroraColors.count - 1))
                    let nextColorIndex = (colorIndex + 1) % greenAuroraColors.count
                    let blend = (phase * Double(greenAuroraColors.count - 1)).truncatingRemainder(dividingBy: 1.0)
                    
                    let currentColor = interpolateColor(
                        from: greenAuroraColors[colorIndex],
                        to: greenAuroraColors[nextColorIndex],
                        progress: blend
                    )
                    
                    // Arc principal - gradient radial centré sous l'écran
                    RadialGradient(
                        colors: [
                            currentColor,
                            currentColor.opacity(0.45),
                            currentColor.opacity(0.28),
                            currentColor.opacity(0.16),
                            currentColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .init(x: 0.5, y: 1.0), // Centré en bas
                        startRadius: 0,
                        endRadius: geometry.size.height * (0.46 + 0.10 * breath) // Breathing radius (slightly larger)
                    )
                    .offset(y: geometry.size.height * (0.10 + 0.035 * breath)) // Slightly higher + motion
                    .blur(radius: 34 + 16 * breath)
                    .opacity(0.48 + 0.18 * breath) // More visible but still subtle
                    .blendMode(.screen) // Blend mode pour superposition douce
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // Interpolation de couleur fluide
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
            blue: Double((1 - p) * b1 + p * b2),
            opacity: Double((1 - p) * a1 + p * a2)
        )
    }
}

