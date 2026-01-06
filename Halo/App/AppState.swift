//
//  AppState.swift
//  Halo
//
//  Global app state management using @Observable pattern
//

import SwiftUI
import Combine

// MARK: - Screen Enum
enum AppScreen: Equatable {
    case splash
    case onboarding
    case processing
    case result
    case paywall
    case home
}

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentScreen: AppScreen = .splash
    @Published var hasCompletedOnboarding: Bool = false
    @Published var capturedImage: UIImage?
    @Published var generatedImage: UIImage?
    @Published var selectedHairstyle: HairstyleOption?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showCameraSheet: Bool = false
    @Published var showHistorySheet: Bool = false
    @Published var showPaywallSheet: Bool = false
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
    
    // MARK: - Init
    init() {
        loadPersistedState()
    }
    
    // MARK: - State Persistence
    private func loadPersistedState() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
    }
    
    func performBootSequence() async {
        // Artificial delay for splash screen
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        
        let destination: AppScreen = hasCompletedOnboarding ? .home : .onboarding
        navigateTo(destination)
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
        navigateTo(.home)
        showCameraSheet = true
    }
    
    
    // MARK: - Navigation
    func navigateTo(_ screen: AppScreen) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            currentScreen = screen
        }
    }
    
    // MARK: - Image Handling
    func setCapturedImage(_ image: UIImage) {
        capturedImage = image
        showCameraSheet = false  // Close the sheet first
        navigateTo(.processing)
    }
    
    func setGeneratedImage(_ image: UIImage) {
        generatedImage = image
        
        // TODO: Save generation logic moved to ProcessingView using GenerationService
        // GenerationService.shared.save...
        
        navigateTo(.result)
    }
    
    // MARK: - Reset
    func reset() {
        capturedImage = nil
        generatedImage = nil
        selectedHairstyle = nil
        errorMessage = nil
    }
    
    func startNewTryOn() {
        reset()
        navigateTo(.home)
        showCameraSheet = true
    }
}

// MARK: - Hairstyle Option
struct HairstyleOption: Identifiable, Equatable {
    let id: String
    let name: String
    let prompt: String
    let thumbnailName: String
    let category: HairstyleCategory
    
    enum HairstyleCategory: String, CaseIterable {
        case trendy = "Trendy"
        case classic = "Classic"
        case bold = "Bold"
        case natural = "Natural"
    }
}

// MARK: - Sample Hairstyles
extension HairstyleOption {
    static let samples: [HairstyleOption] = [
        // Trendy
        HairstyleOption(
            id: "wolf_cut",
            name: "Wolf Cut",
            prompt: "Transform the person's hairstyle to a trendy wolf cut with shaggy layers, face-framing pieces, and textured ends. Keep the face exactly the same, only change the hair.",
            thumbnailName: "hair_wolf",
            category: .trendy
        ),
        HairstyleOption(
            id: "curtain_bangs",
            name: "Curtain Bangs",
            prompt: "Add beautiful curtain bangs that frame the face softly, parted in the middle with flowing sides. Keep the face exactly the same, only add the bangs.",
            thumbnailName: "hair_curtain",
            category: .trendy
        ),
        HairstyleOption(
            id: "butterfly_cut",
            name: "Butterfly Cut",
            prompt: "Transform to a butterfly cut with voluminous layers that create movement, shorter layers on top and longer at the bottom. Keep the face exactly the same.",
            thumbnailName: "hair_butterfly",
            category: .trendy
        ),
        
        // Classic
        HairstyleOption(
            id: "bob",
            name: "Classic Bob",
            prompt: "Transform the hairstyle to a sleek classic bob cut, chin-length with clean lines and slight inward curl at the ends. Keep the face exactly the same.",
            thumbnailName: "hair_bob",
            category: .classic
        ),
        HairstyleOption(
            id: "long_layers",
            name: "Long Layers",
            prompt: "Give the person beautiful long layered hair with soft, flowing layers that add movement and dimension. Keep the face exactly the same.",
            thumbnailName: "hair_layers",
            category: .classic
        ),
        HairstyleOption(
            id: "pixie",
            name: "Pixie Cut",
            prompt: "Transform to an elegant pixie cut, short and chic with textured top and tapered sides. Keep the face exactly the same, only change the hair.",
            thumbnailName: "hair_pixie",
            category: .classic
        ),
        
        // Bold
        HairstyleOption(
            id: "buzz_fade",
            name: "Buzz Fade",
            prompt: "Transform to a stylish buzz cut with a clean fade on the sides and slightly longer on top. Keep the face exactly the same.",
            thumbnailName: "hair_buzz",
            category: .bold
        ),
        HairstyleOption(
            id: "mohawk",
            name: "Modern Mohawk",
            prompt: "Give a modern mohawk hairstyle with the sides faded and a styled strip of longer hair on top. Keep the face exactly the same.",
            thumbnailName: "hair_mohawk",
            category: .bold
        ),
        HairstyleOption(
            id: "shaved_sides",
            name: "Shaved Sides",
            prompt: "Create an edgy look with shaved sides and longer hair on top that can be styled to one side. Keep the face exactly the same.",
            thumbnailName: "hair_shaved",
            category: .bold
        ),
        
        // Natural
        HairstyleOption(
            id: "afro",
            name: "Natural Afro",
            prompt: "Transform to a beautiful natural afro hairstyle, full and voluminous with natural texture. Keep the face exactly the same.",
            thumbnailName: "hair_afro",
            category: .natural
        ),
        HairstyleOption(
            id: "braids",
            name: "Box Braids",
            prompt: "Give the person elegant box braids, medium-sized and neatly done, falling past the shoulders. Keep the face exactly the same.",
            thumbnailName: "hair_braids",
            category: .natural
        ),
        HairstyleOption(
            id: "locs",
            name: "Locs",
            prompt: "Transform the hairstyle to beautiful well-maintained locs, styled elegantly. Keep the face exactly the same.",
            thumbnailName: "hair_locs",
            category: .natural
        )
    ]
}
