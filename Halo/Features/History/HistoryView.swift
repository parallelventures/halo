//
//  HistoryView.swift
//  Halo
//
//  User's hairstyle generation history
//

import SwiftUI

struct HistoryView: View {
    
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storageService = SupabaseStorageService.shared
    
    @State private var selectedGeneration: HairstyleGeneration?
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                // Main content with top padding for custom nav bar
                VStack(spacing: 0) {
                    Color.clear.frame(height: 60) // Spacer for nav bar
                    
                    if storageService.isLoading && storageService.generations.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    } else if storageService.generations.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        historyGrid
                    }
                }
                
                // Custom Navigation Bar
                HStack {
                    // Close Button
                    Button {
                        appState.showHistorySheet = false
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    
                    Spacer()
                    
                    Text("History")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(height: 60)
                .background(
                    Color.black.opacity(0.8)
                        .ignoresSafeArea(edges: .top)
                        .blur(radius: 20)
                )
            }
            .navigationBarHidden(true)
        }
        .task {
            await storageService.fetchHistory()
        }
        .sheet(item: $selectedGeneration) { generation in
            HistoryDetailView(generation: generation)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No hairstyles yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
            
            Text("Your generated hairstyles will appear here")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
            
            Button {
                appState.showCameraSheet = true
            } label: {
                Text("Try Your First Look")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
            }
            .padding(.top, 8)
        }
    }
    
    private var historyGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(storageService.generations) { generation in
                    HistoryCell(generation: generation)
                        .onTapGesture {
                            selectedGeneration = generation
                        }
                }
            }
            .padding(16)
        }
        .refreshable {
            await storageService.fetchHistory()
        }
    }
}

// MARK: - History Cell
struct HistoryCell: View {
    let generation: HairstyleGeneration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Image
            AsyncImage(url: generation.imageURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay(ProgressView().tint(.white))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white.opacity(0.3))
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(generation.styleName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(generation.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - History Detail View
struct HistoryDetailView: View {
    let generation: HairstyleGeneration
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Image
                    AsyncImage(url: generation.imageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .aspectRatio(3/4, contentMode: .fit)
                                .overlay(ProgressView().tint(.white))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .aspectRatio(3/4, contentMode: .fit)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    
                    // Info
                    VStack(spacing: 8) {
                        Text(generation.styleName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let category = generation.styleCategory, !category.isEmpty {
                            Text(category)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Text(generation.createdAt.formatted(date: .long, time: .shortened))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    // Actions - Download & Share
                    HStack(spacing: 12) {
                        // Download Button - Clear Glass
                        Button {
                            downloadImage()
                        } label: {
                            Text("Download")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .glassButtonCapsule(style: .clear)
                        
                        // Share Button - White Glass
                        Button {
                            shareImage()
                        } label: {
                            Text("Share")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .glassButtonCapsule(style: .white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Delete Button - Top Left
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                    }
                }
                
                // Done Button - Top Right
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .confirmationDialog("Delete this hairstyle?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await SupabaseStorageService.shared.deleteGeneration(generation)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareImage() {
        guard let url = generation.imageURL else { return }
        
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                
                await MainActor.run {
                    let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            }
        }
    }
    
    private func downloadImage() {
        guard let url = generation.imageURL else { return }
        
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                
                await MainActor.run {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    HapticManager.success()
                }
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}

// MARK: - Glass Button Capsule Extension
enum GlassCapsuleStyle {
    case clear
    case white
}

extension View {
    @ViewBuilder
    func glassButtonCapsule(style: GlassCapsuleStyle) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .clear:
                self
                    .background(.clear)
                    .glassEffect(.regular, in: .capsule)
            case .white:
                self
                    .background(Color.white)
                    .clipShape(Capsule())
                    .glassEffect(.regular, in: .capsule)
            }
        } else {
            switch style {
            case .clear:
                self
                    .background(.ultraThinMaterial, in: Capsule())
            case .white:
                self
                    .background(Color.white, in: Capsule())
            }
        }
    }
}
