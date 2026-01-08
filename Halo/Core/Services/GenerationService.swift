//
//  GenerationService.swift
//  Halo
//
//  Service to sync generations with Supabase
//

import Foundation
import UIKit

// MARK: - Generation Model
struct Generation: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var originalImageUrl: String?
    var generatedImageUrl: String?
    var thumbnailUrl: String?
    var styleName: String?
    var styleCategory: String?
    var stylePrompt: String?
    var status: GenerationStatus
    var errorMessage: String?
    var processingTimeMs: Int?
    var isFavorite: Bool
    var isDeleted: Bool
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case originalImageUrl = "original_image_url"
        case generatedImageUrl = "generated_image_url"
        case thumbnailUrl = "thumbnail_url"
        case styleName = "style_name"
        case styleCategory = "style_category"
        case stylePrompt = "style_prompt"
        case status
        case errorMessage = "error_message"
        case processingTimeMs = "processing_time_ms"
        case isFavorite = "is_favorite"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum GenerationStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
}

// MARK: - Generation Service
@MainActor
class GenerationService: ObservableObject {
    static let shared = GenerationService()
    
    private let supabase = SupabaseService.shared
    private let bucketName = "generations"
    
    @Published var generations: [Generation] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Create New Generation
    func createGeneration(
        originalImage: UIImage,
        styleName: String,
        styleCategory: String,
        stylePrompt: String
    ) async -> Generation? {
        guard let userId = supabase.currentUser?.id else {
            error = "User not logged in"
            return nil
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 1. Upload original image to Storage
            let originalImageUrl = try await uploadImage(originalImage, userId: userId, type: "original")
            
            // 2. Create generation record
            let generationId = UUID()
            let record: [String: Any] = [
                "id": generationId.uuidString,
                "user_id": userId.uuidString,
                "original_image_url": originalImageUrl ?? "",
                "style_name": styleName,
                "style_category": styleCategory,
                "style_prompt": stylePrompt,
                "status": "pending",
                "is_favorite": false,
                "is_deleted": false
            ]
            
            try await supabase.client
                .from("generations")
                .insert(record)
                .execute()
            
            print("✅ Generation created: \(generationId)")
            
            // Track with TikTok SDK
            TikTokService.shared.trackStyleSelected(
                styleId: generationId.uuidString,
                styleName: styleName,
                category: styleCategory
            )
            
            // Return the created generation
            return Generation(
                id: generationId,
                userId: userId,
                originalImageUrl: originalImageUrl,
                generatedImageUrl: nil,
                thumbnailUrl: nil,
                styleName: styleName,
                styleCategory: styleCategory,
                stylePrompt: stylePrompt,
                status: .pending,
                errorMessage: nil,
                processingTimeMs: nil,
                isFavorite: false,
                isDeleted: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            
        } catch {
            self.error = "Failed to create generation: \(error.localizedDescription)"
            print("❌ \(self.error!)")
            return nil
        }
    }
    
    // MARK: - Update Generation with Result
    func updateGenerationResult(
        generationId: UUID,
        generatedImage: UIImage,
        processingTimeMs: Int
    ) async -> Bool {
        guard let userId = supabase.currentUser?.id else { return false }
        
        do {
            // 1. Upload generated image
            let generatedImageUrl = try await uploadImage(generatedImage, userId: userId, type: "generated_\(generationId.uuidString)")
            
            // 2. Create thumbnail
            let thumbnail = generatedImage.preparingThumbnail(of: CGSize(width: 200, height: 200))
            let thumbnailUrl = try await uploadImage(thumbnail ?? generatedImage, userId: userId, type: "thumb_\(generationId.uuidString)")
            
            // 3. Update record
            try await supabase.client
                .from("generations")
                .update([
                    "generated_image_url": generatedImageUrl ?? "",
                    "thumbnail_url": thumbnailUrl ?? "",
                    "status": "completed",
                    "processing_time_ms": processingTimeMs,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: generationId.uuidString)
                .execute()
            
            print("✅ Generation updated with result")
            return true
            
        } catch {
            // Mark as failed
            try? await supabase.client
                .from("generations")
                .update([
                    "status": "failed",
                    "error_message": error.localizedDescription
                ])
                .eq("id", value: generationId.uuidString)
                .execute()
            
            print("❌ Failed to update generation: \(error)")
            return false
        }
    }
    
    // MARK: - Fetch User's Generations (History)
    func fetchGenerations() async {
        guard let userId = supabase.currentUser?.id else {
            generations = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await supabase.client
                .from("generations")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_deleted", value: false)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            generations = try decoder.decode([Generation].self, from: response.data)
            
            print("✅ Fetched \(generations.count) generations")
            
        } catch {
            self.error = "Failed to fetch generations: \(error.localizedDescription)"
            print("❌ \(self.error!)")
        }
    }
    
    // MARK: - Toggle Favorite
    func toggleFavorite(generationId: UUID) async {
        guard let index = generations.firstIndex(where: { $0.id == generationId }) else { return }
        
        let newValue = !generations[index].isFavorite
        generations[index].isFavorite = newValue
        
        do {
            try await supabase.client
                .from("generations")
                .update(["is_favorite": newValue])
                .eq("id", value: generationId.uuidString)
                .execute()
            
            print("✅ Favorite toggled: \(newValue)")
        } catch {
            // Revert on failure
            generations[index].isFavorite = !newValue
            print("❌ Failed to toggle favorite: \(error)")
        }
    }
    
    // MARK: - Delete Generation (Soft Delete)
    func deleteGeneration(generationId: UUID) async {
        generations.removeAll { $0.id == generationId }
        
        do {
            try await supabase.client
                .from("generations")
                .update(["is_deleted": true])
                .eq("id", value: generationId.uuidString)
                .execute()
            
            print("✅ Generation deleted")
        } catch {
            print("❌ Failed to delete generation: \(error)")
            // Refetch to restore
            await fetchGenerations()
        }
    }
    
    // MARK: - Upload Image to Storage
    private func uploadImage(_ image: UIImage, userId: UUID, type: String) async throws -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileName = "\(userId.uuidString)/\(type)_\(UUID().uuidString).jpg"
        
        try await supabase.client.storage
            .from(bucketName)
            .upload(path: fileName, file: imageData, options: .init(contentType: "image/jpeg"))
        
        // Get public URL
        let url = try supabase.client.storage
            .from(bucketName)
            .getPublicURL(path: fileName)
        
        return url.absoluteString
    }
    
    // MARK: - Download Image
    func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("❌ Failed to download image: \(error)")
            return nil
        }
    }
}

// MARK: - Local History Cache
extension GenerationService {
    private var cacheKey: String { "cached_generations" }
    
    func cacheGenerations() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(generations) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    func loadCachedGenerations() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let cached = try? decoder.decode([Generation].self, from: data) {
            generations = cached
        }
    }
}
