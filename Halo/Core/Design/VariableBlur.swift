//
//  VariableBlur.swift
//  Halo
//
//  Variable blur effect for progressive masking
//

import Foundation
import SwiftUI
import UIKit

extension UIBlurEffect {
    public static func variableBlurEffect(radius: Double, imageMask: UIImage) -> UIBlurEffect? {
        let methodType = (@convention(c) (AnyClass, Selector, Double, UIImage) -> UIBlurEffect).self
        let selectorName = ["imageMask:", "effectWithVariableBlurRadius:"].reversed().joined()
        let selector = NSSelectorFromString(selectorName)

        guard UIBlurEffect.responds(to: selector) else { return nil }

        let implementation = UIBlurEffect.method(for: selector)
        let method = unsafeBitCast(implementation, to: methodType)

        return method(UIBlurEffect.self, selector, radius, imageMask)
    }
}

struct VariableBlurView: UIViewRepresentable {
    let radius: Double
    let mask: Image

    func makeUIView(context: Context) -> UIVisualEffectView {
        let maskImage = ImageRenderer(content: mask).uiImage
        let effect = maskImage.flatMap {
            UIBlurEffect.variableBlurEffect(radius: radius, imageMask: $0)
        }
        return UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        let maskImage = ImageRenderer(content: mask).uiImage
        view.effect = maskImage.flatMap {
            UIBlurEffect.variableBlurEffect(radius: radius, imageMask: $0)
        }
    }
}

extension Image {
    // ULTRA-OPTIMISÉ - Génération async + cache persistant
    @MainActor
    static var progressiveBlurMask: Image {
        if let cached = _progressiveBlurMaskCache {
            return cached
        }
        
        // Fallback immédiat avec gradient simple
        let fallbackImage = Image(uiImage: Self.createFallbackGradient())
        _progressiveBlurMaskCache = fallbackImage
        
        // Génération async de la vraie version (simplifiée)
        Task.detached {
            await MainActor.run {
                let renderer = ImageRenderer(
                    content: LinearGradient(
                        colors: [
                            .black.opacity(0.5), .black.opacity(0.48), .black.opacity(0.46),
                            .black.opacity(0.44), .black.opacity(0.42), .black.opacity(0.40),
                            .black.opacity(0.38), .black.opacity(0.36), .black.opacity(0.34),
                            .black.opacity(0.32), .black.opacity(0.30), .black.opacity(0.28),
                            .black.opacity(0.26), .black.opacity(0.24), .black.opacity(0.22),
                            .black.opacity(0.20), .black.opacity(0.18), .black.opacity(0.16),
                            .black.opacity(0.14), .black.opacity(0.12), .black.opacity(0.10),
                            .black.opacity(0.08), .black.opacity(0.06), .black.opacity(0.04),
                            .black.opacity(0.02), .black.opacity(0.01), .black.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                )
                _progressiveBlurMaskCache = Image(uiImage: renderer.uiImage ?? UIImage())
            }
        }
        
        return fallbackImage
    }
    
    // Gradient de fallback ultra-léger
    private static func createFallbackGradient() -> UIImage {
        let size = CGSize(width: 100, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = [UIColor.black.withAlphaComponent(0.5), UIColor.clear]
            let cgColors = colors.map { $0.cgColor }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors as CFArray, locations: [0, 1])!
            
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }
    
    @MainActor
    static var progressiveBlurMaskBottom: Image {
        if let cached = _progressiveBlurMaskBottomCache {
            return cached
        }
        
        let image = ImageRenderer(
            content: LinearGradient(
                colors: [
                    .black.opacity(0),
                    .black.opacity(0.05),
                    .black.opacity(0.1),
                    .black.opacity(0.2),
                    .black.opacity(0.35),
                    .black.opacity(0.5),
                    .black.opacity(0.65),
                    .black.opacity(0.75),
                    .black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        )
        
        let result = Image(uiImage: image.uiImage ?? UIImage())
        _progressiveBlurMaskBottomCache = result
        return result
    }
    
    @MainActor
    static var taskCardBlurMask: Image {
        if let cached = _taskCardBlurMaskCache {
            return cached
        }
        
        let image = ImageRenderer(
            content: LinearGradient(
                colors: [
                    .black.opacity(0),
                    .black.opacity(0.1),
                    .black.opacity(0.3),
                    .black.opacity(0.5),
                    .black.opacity(0.7),
                    .black.opacity(0.85),
                    .black.opacity(1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 180, height: 80)
        )
        
        let result = Image(uiImage: image.uiImage ?? UIImage())
        _taskCardBlurMaskCache = result
        return result
    }
    
    @MainActor
    static var tabBarProgressiveBlurMask: Image {
        if let cached = _tabBarBlurMaskCache {
            return cached
        }
        
        let image = ImageRenderer(
            content: LinearGradient(
                colors: [
                    .black.opacity(1.0),    // Full blur at bottom
                    .black.opacity(0.95),
                    .black.opacity(0.85),
                    .black.opacity(0.7),
                    .black.opacity(0.5),
                    .black.opacity(0.3),
                    .black.opacity(0.15),
                    .black.opacity(0.05),
                    .black.opacity(0)       // No blur at top
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 100)
        )
        
        let result = Image(uiImage: image.uiImage ?? UIImage())
        _tabBarBlurMaskCache = result
        return result
    }
    
    // Cache privé pour éviter de recalculer
    @MainActor private static var _progressiveBlurMaskCache: Image?
    @MainActor private static var _progressiveBlurMaskBottomCache: Image?
    @MainActor private static var _taskCardBlurMaskCache: Image?
    @MainActor private static var _tabBarBlurMaskCache: Image?
}
