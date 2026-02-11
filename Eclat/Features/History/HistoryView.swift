//
//  HistoryView.swift
//  Eclat
//
//  "Your Transformations"
//  A premium, identity-focused history gallery.
//  Encourages re-try and emotional connection with past looks.
//

import SwiftUI

struct HistoryView: View {
    
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var generationService = GenerationService.shared
    
    // Grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Deep Background
                Color(hex: "0B0606").ignoresSafeArea()
                
                if generationService.isLoading && generationService.generations.isEmpty {
                    ProgressView().tint(.white)
                } else if generationService.generations.isEmpty {
                    emptyState
                } else {
                    mainScrollView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your transformations")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.showHistorySheet = false
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        .onAppear {
            Task {
                await generationService.fetchGenerations()
            }
        }
    }
    
    // MARK: - Main Content
    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 32) {
                
                // HERO SECTION (Latest Look)
                if let firstGen = generationService.generations.first {
                    VStack(alignment: .leading, spacing: 12) {
                        // Badge
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                            Text("Your latest look")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 4)
                        
                        // Hero Card
                        HeroHistoryCard(generation: firstGen)
                            .onTapGesture {
                                HapticManager.shared.buttonPress()
                                openResultView(for: firstGen)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // PREVIOUS LOOKS (Grouped by Date)
                let previousGenerations = Array(generationService.generations.dropFirst())
                if !previousGenerations.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Section Title
                        Text("Previous transformations")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        // Grid
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(previousGenerations) { generation in
                                StandardHistoryCard(generation: generation)
                                    .onTapGesture {
                                        HapticManager.shared.buttonPress()
                                        openResultView(for: generation)
                                    }
                                    .contextMenu {
                                        Button {
                                            openResultView(for: generation)
                                        } label: {
                                            Label("View Transformation", systemImage: "eye")
                                        }
                                        
                                        Button(role: .destructive) {
                                            Task {
                                                await generationService.deleteGeneration(generationId: generation.id)
                                            }
                                        } label: {
                                            Label("Delete Look", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // FOOTER UPSELL (Subtle)
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 40)
                    
                    VStack(spacing: 8) {
                        Text("Want to explore more versions of you?")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Try new looks anytime.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Button {
                        appState.navigateTo(.creditsPaywall)
                        appState.showHistorySheet = false
                    } label: {
                        Text("Get more looks")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white, in: Capsule())
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 40)
                .padding(.bottom, 20)
                
            }
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                Text("Start your evolution")
                    .font(.eclat.displayMedium) // or system semibold 22
                    .foregroundColor(.white)
                
                Text("Your transformations will appear here.\nCreate your first look now.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button {
                appState.showCameraSheet = true
                dismiss()
            } label: {
                Text("Create First Look")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 200, height: 50)
                    .background(Color.white, in: Capsule())
            }
            .padding(.top, 16)
            
            Spacer()
        }
        .padding(32)
    }
    
    // MARK: - Actions
    private func openResultView(for generation: Generation) {
        Task {
            // Haptic Feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            if let path = generation.generatedImageUrl,
               let image = try? await GenerationService.shared.downloadAuthenticatedImage(path: path) {
                
                await MainActor.run {
                    appState.generatedImage = image
                    
                    if let styleName = generation.styleName {
                        appState.selectedHairstyle = Hairstyle(
                            name: styleName,
                            category: GenderCategory(rawValue: generation.styleCategory ?? "") ?? .women,
                            length: .medium,
                            texture: .straight,
                            tags: [],
                            description: "History item",
                            imageName: nil
                        )
                    }
                    
                    appState.showHistorySheet = false
                    dismiss()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.navigateTo(.result)
                    }
                }
            } else {
                // Soft Fail Handling (Future: Show error card instead of navigating)
                // For now, silent fail is better than crash
            }
        }
    }
}

// MARK: - Components

struct HeroHistoryCard: View {
    let generation: Generation
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            SecureGenerationImage(path: generation.generatedImageUrl)
                .aspectRatio(3/4, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            
            // Gradient Overlay
            LinearGradient(
                colors: [.black.opacity(0.8), .transparent],
                startPoint: .bottom,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            // Text Content
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(generation.styleName ?? "Unknown Style")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Tap to see again")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .opacity(0.8)
            }
            .padding(20)
        }
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

struct StandardHistoryCard: View {
    let generation: Generation
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SecureGenerationImage(path: generation.thumbnailUrl ?? generation.generatedImageUrl)
                .aspectRatio(3/4, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Subtle Gradient
            LinearGradient(
                colors: [.black.opacity(0.7), .transparent],
                startPoint: .bottom,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Info
            Text(generation.styleName ?? "Style")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(12)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20)) // Hit testing
    }
}

// Reuse existing SecureGenerationImage component
// (Included here for completeness if replacing entire file)
struct SecureGenerationImage: View {
    let path: String?
    var onImageLoaded: ((UIImage) -> Void)? = nil
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasError = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay {
                            if isLoading {
                                ProgressView().tint(.white.opacity(0.5))
                            } else if hasError {
                                VStack(spacing: 8) {
                                    Image(systemName: "eye.slash")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("Not available")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                        }
                }
            }
        }
        .task {
            await load()
        }
        .onChange(of: path) { _, _ in Task { await load() } }
    }
    
    private func load() async {
        guard let path = path, !path.isEmpty else { return }
        isLoading = true
        hasError = false
        
        // Cache check could be here
        
        do {
            if let loaded = try? await GenerationService.shared.downloadAuthenticatedImage(path: path) {
                self.image = loaded
                onImageLoaded?(loaded)
            } else {
                hasError = true
            }
        }
        isLoading = false
    }
}

extension Color {
    static let transparent = Color.black.opacity(0)
}
