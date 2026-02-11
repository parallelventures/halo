//
//  HairColorData.swift
//  Eclat
//
//  Catalog of hair colors for "Color Styles" feature.
//  Enhances retention by extending the decision loop.
//

import Foundation

// Definitions moved to AppState.swift to resolve scope issues

// MARK: - Catalog
struct HairColorData {
    
    static let allColors: [HairColor] = [
        // --- Safe / Natural ---
        HairColor(
            id: "color_jet_noir",
            name: "Jet Noir",
            imageName: "jet-noir",
            category: .safe,
            promptModifier: "jet black hair color, deep shiny black"
        ),
        HairColor(
            id: "color_toasted_chestnut",
            name: "Toasted Chestnut",
            imageName: "toasted-chestnut",
            category: .safe,
            promptModifier: "toasted chestnut brown hair color, warm brown tones"
        ),
        HairColor(
            id: "color_sunkissed_butter",
            name: "Sunkissed Butter",
            imageName: "sunkissed-butter",
            category: .safe,
            promptModifier: "sunkissed butter blonde, warm golden blonde"
        ),
        
        // --- Premium ---
        HairColor(
            id: "color_vanilla_blonde",
            name: "Vanilla Blonde",
            imageName: "vanilla-blonde",
            category: .premium,
            promptModifier: "vanilla blonde hair color, creamy pale blonde, soft tones"
        ),
        HairColor(
            id: "color_midnight_expresso",
            name: "Midnight Expresso",
            imageName: "midnight-expresso",
            category: .premium,
            promptModifier: "midnight espresso hair color, very dark cool brown"
        ),
        
        // --- Bold ---
        HairColor(
            id: "color_couture_red",
            name: "Couture Red",
            imageName: "couture-red",
            category: .bold,
            promptModifier: "couture red hair color, vibrant distinct red, fashion color"
        ),
        HairColor(
            id: "color_platinum_ice",
            name: "Platinum Ice",
            imageName: "platinum-ice",
            category: .bold,
            promptModifier: "platinum ice blonde hair color, cool snowy white blonde"
        )
    ]
    
    // MARK: - Helpers
    static func colors(for category: HairColorCategory) -> [HairColor] {
        allColors.filter { $0.category == category }
    }
}
