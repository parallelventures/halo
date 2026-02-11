//
//  AccountGlassEffect.swift
//  Eclat
//
//  Glass effect modifier for account sections
//

import SwiftUI

extension View {
    @ViewBuilder
    func applyAccountGlassEffect() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        } else {
            self
                .background(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}
