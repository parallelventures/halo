//
//  FunnelExperimentService.swift
//  Eclat
//
//  A/B/C Split Test for paywall funnels
//  Synced with RevenueCat Experiments + TikTok attribution
//

import Foundation
import RevenueCat

// MARK: - Funnel Variant
enum FunnelVariant: String, CaseIterable, Codable {
    case A = "hard_paywall_upfront"      // Projection-first: Blur → Pay
    case B = "paywall_post_result"       // Proof-first: Generate → Reveal → Upsell
    case C = "commitment_first"          // Commitment-first: Engage → Tension → Pay
    
    var displayName: String {
        switch self {
        case .A: return "Variante A"
        case .B: return "Variante B"
        case .C: return "Variante C"
        }
    }
    
    var description: String {
        switch self {
        case .A: return "Hard Paywall (Projection-first)"
        case .B: return "Post-Result Paywall (Proof-first)"
        case .C: return "Commitment-first Paywall"
        }
    }
    
    /// Weight for random assignment (33/33/33)
    static var weights: [FunnelVariant: Double] {
        [.A: 0.33, .B: 0.33, .C: 0.34]
    }
}

// MARK: - Funnel Experiment Service
@MainActor
final class FunnelExperimentService: ObservableObject {
    
    static let shared = FunnelExperimentService()
    
    // MARK: - Published Properties
    @Published private(set) var currentVariant: FunnelVariant = .A
    @Published private(set) var isAssigned: Bool = false
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let assignedVariant = "funnel_experiment_variant"
        static let assignedAt = "funnel_experiment_assigned_at"
        static let experimentVersion = "funnel_experiment_version"
    }
    
    // Increment this to reset all users to a new experiment
    private let currentExperimentVersion = 1
    
    // MARK: - Init
    private init() {
        loadOrAssignVariant()
    }
    
    // MARK: - Load or Assign Variant
    private func loadOrAssignVariant() {
        let savedVersion = UserDefaults.standard.integer(forKey: Keys.experimentVersion)
        
        // Check if we have a saved variant from current experiment version
        if savedVersion == currentExperimentVersion,
           let savedVariantRaw = UserDefaults.standard.string(forKey: Keys.assignedVariant),
           let savedVariant = FunnelVariant(rawValue: savedVariantRaw) {
            currentVariant = savedVariant
            isAssigned = true
            print("🧪 Loaded existing variant: \(savedVariant.rawValue)")
        } else {
            // Assign new variant randomly (weighted 33/33/34)
            assignRandomVariant()
        }
        
        // Sync to RevenueCat
        syncToRevenueCat()
    }
    
    // MARK: - Assign Random Variant
    private func assignRandomVariant() {
        let random = Double.random(in: 0...1)
        var cumulative: Double = 0
        
        for (variant, weight) in FunnelVariant.weights {
            cumulative += weight
            if random <= cumulative {
                currentVariant = variant
                break
            }
        }
        
        // Persist
        UserDefaults.standard.set(currentVariant.rawValue, forKey: Keys.assignedVariant)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.assignedAt)
        UserDefaults.standard.set(currentExperimentVersion, forKey: Keys.experimentVersion)
        
        isAssigned = true
        print("🧪 Assigned NEW variant: \(currentVariant.rawValue)")
    }
    
    // MARK: - Sync to RevenueCat
    private func syncToRevenueCat() {
        Task {
            do {
                // Set variant as a subscriber attribute for RevenueCat Experiments
                Purchases.shared.attribution.setAttributes([
                    "funnel_variant": currentVariant.rawValue,
                    "funnel_variant_letter": String(currentVariant.rawValue.prefix(1)).uppercased(),
                    "experiment_version": String(currentExperimentVersion)
                ])
                print("✅ Synced variant to RevenueCat: \(currentVariant.rawValue)")
            }
        }
    }
    
    // MARK: - Force Variant (Dev/Debug only)
    func forceVariant(_ variant: FunnelVariant) {
        currentVariant = variant
        UserDefaults.standard.set(variant.rawValue, forKey: Keys.assignedVariant)
        syncToRevenueCat()
        print("🔧 DEV: Forced variant to \(variant.rawValue)")
    }
    
    // MARK: - Reset Experiment (Dev/Debug only)
    func resetExperiment() {
        UserDefaults.standard.removeObject(forKey: Keys.assignedVariant)
        UserDefaults.standard.removeObject(forKey: Keys.assignedAt)
        UserDefaults.standard.removeObject(forKey: Keys.experimentVersion)
        isAssigned = false
        loadOrAssignVariant()
        print("🔧 DEV: Reset experiment - new variant: \(currentVariant.rawValue)")
    }
    
    // MARK: - Get Variant for TikTok Events
    var variantForTracking: String {
        currentVariant.rawValue
    }
    
    var variantLetter: String {
        switch currentVariant {
        case .A: return "A"
        case .B: return "B"
        case .C: return "C"
        }
    }
}
