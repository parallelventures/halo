//
//  HistoryView.swift
//  Halo
//
//  User's hairstyle generation history
//

import SwiftUI

struct HistoryView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var storageService = SupabaseStorageService.shared
    
    @State private var selectedGeneration: HairstyleGeneration?
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if storageService.isLoading && storageService.generations.isEmpty {
                    ProgressView()
                        .tint(.white)
                } else if storageService.generations.isEmpty {
                    emptyState
                } else {
                    historyGrid
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.navigateTo(.home)
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
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
                appState.navigateTo(.camera)
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
                    
                    // Actions
                    HStack(spacing: 16) {
                        Button {
                            shareImage()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}
