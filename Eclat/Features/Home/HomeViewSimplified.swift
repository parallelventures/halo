//
//  HomeViewSimplified.swift
//  Eclat
//
//  Simplified home with 3 sections showing only available styles
//

import SwiftUI
import PhotosUI

struct HomeViewSimplified: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var generationService = GenerationService.shared
    
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showAccountSheet = false
    
    // Only styles with available images
    private var availableStyles: [Hairstyle] {
        HairstyleData.women.filter { $0.imageName != nil }
    }
    
    // Split into 3 sections
    private var trendingStyles: [Hairstyle] {
        Array(availableStyles.filter { $0.tags.contains("trendy") }.prefix(6))
    }
    
    private var popularStyles: [Hairstyle] {
        Array(availableStyles.filter { $0.tags.contains("popular") && !$0.tags.contains("trendy") }.prefix(6))
    }
    
    private var iconicStyles: [Hairstyle] {
        Array(availableStyles.filter { $0.tags.contains("iconic") && !$0.tags.contains("trendy") && !$0.tags.contains("popular") }.prefix(6))
    }
    
    // New hairstyles section - explicitly show these 4 new styles
    private var newHairstyles: [Hairstyle] {
        let newStyleNames = ["Wolf Cut", "Wavy Lob", "Defined Curls", "The Italian Bob"]
        return availableStyles.filter { newStyleNames.contains($0.name) }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0B0606")
            
            // Main content
            ZStack(alignment: .top) {
                // ScrollView
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Spacer for header
                        Color.clear.frame(height: 70)
                        
                        // MARK: - Hero
                        VStack(spacing: 12) {
                            Text("Try Your New Look")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Discover hairstyles with AI")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 20)
                        
                        // MARK: - New Hairstyles Section
                        if !newHairstyles.isEmpty {
                            StyleSectionSimplified(title: "New Hairstyles ✨", styles: newHairstyles, appState: appState)
                        }
                        
                        // MARK: - Trending Section
                        if !trendingStyles.isEmpty {
                            StyleSectionSimplified(title: "Trending Now", styles: trendingStyles, appState: appState)
                        }
                        
                        // MARK: - Popular Section
                        if !popularStyles.isEmpty {
                            StyleSectionSimplified(title: "Popular Styles", styles: popularStyles, appState: appState)
                        }
                        
                        // MARK: - Iconic Section
                        if !iconicStyles.isEmpty {
                            StyleSectionSimplified(title: "Iconic Looks", styles: iconicStyles, appState: appState)
                        }
                        
                        // Bottom padding for CTA
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
                
                // MARK: - Variable Blur Layer
                VStack {
                    VariableBlurView(radius: 15, mask: .progressiveBlurMask)
                        .frame(height: 100)
                        .ignoresSafeArea(edges: .top)
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // MARK: - Sticky Header
                headerView
            }
            
            // MARK: - Bottom CTA
            bottomCTA
        }
        .task {
            await generationService.fetchGenerations()
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheetOpal()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // Logo
            Text("Eclat")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // History & Account buttons
            HStack(spacing: 12) {
                Button {
                    appState.currentScreen = .result
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Button {
                    showAccountSheet = true
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .background(.clear)
    }
    
    // MARK: - Bottom CTA
    private var bottomCTA: some View {
        VStack {
            Spacer()
            
            Button {
                appState.currentScreen = .onboarding
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Try a New Style")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Style Section Component
struct StyleSectionSimplified: View {
    let title: String
    let styles: [Hairstyle]
    let appState: AppState
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Title
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Grid of style cards
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(styles) { style in
                    StyleCardSimplified(style: style)
                        .onTapGesture {
                            appState.selectedHairstyle = style
                            appState.currentScreen = .onboarding
                        }
                }
            }
        }
    }
}

// MARK: - Style Card (9:16 ratio)
struct StyleCardSimplified: View {
    let style: Hairstyle
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            if let imageName = style.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .aspectRatio(9/16, contentMode: .fit)
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Style name
            VStack(alignment: .leading, spacing: 4) {
                Text(style.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
