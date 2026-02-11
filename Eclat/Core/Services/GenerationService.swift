//
//  GenerationService.swift
//  Eclat
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
    
    // MARK: - Generation History Stats
    /// Number of completed generations (for display purposes only, NOT for limiting)
    var generationsCompleted: Int {
        generations.filter { $0.status == .completed }.count
    }
    
    // MARK: - Create New Generation
    func createGeneration(
        originalImage: UIImage,
        styleName: String,
        styleCategory: String,
        stylePrompt: String? = nil // Optional: uses NanoBanana prompts if nil
    ) async -> Generation? {
        guard let userId = supabase.currentUser?.id else {
            error = "User not logged in"
            return nil
        }
        
        // Note: Generation limits are handled by SubscriptionManager (weekly looks)
        // and CreditsService (credit packs). No hardcoded limit here.
        print("📊 Total generations completed: \(generationsCompleted)")
        
        // Use optimized NanoBanana prompt if no custom prompt provided
        let finalPrompt: String
        if let customPrompt = stylePrompt {
            finalPrompt = customPrompt
        } else if let nanoBananaPrompt = NanoBananaWomenHairOnlyPrompts.prompt(for: styleName) {
            finalPrompt = nanoBananaPrompt.json
            print("✅ Using optimized NanoBanana prompt for: \(styleName)")
        } else {
            // Fallback to basic prompt
            finalPrompt = """
            {
              "task": "hairstyle_generation",
              "style": "\(styleName)",
              "category": "\(styleCategory)",
              "preserve_identity": true
            }
            """
            print("⚠️ No NanoBanana prompt for: \(styleName), using fallback")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 1. Upload original image to Storage
            let originalImageUrl = try await uploadImage(originalImage, userId: userId, type: "original")
            
            // 2. Create generation record
            let generationId = UUID()
            let record: [String: Any] = [
                "id": generationId.uuidString.lowercased(),
                "user_id": userId.uuidString.lowercased(),
                "original_image_url": originalImageUrl ?? "",
                "style_name": styleName,
                "style_category": styleCategory.lowercased(),
                "style_prompt": finalPrompt,
                "status": "pending",
                "is_favorite": false,
                "is_deleted": false,
                "created_at": ISO8601DateFormatter().string(from: Date()),
                "updated_at": ISO8601DateFormatter().string(from: Date())
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
            
            // Refresh the list to include new generation
            await fetchGenerations()
            
            // Return the created generation
            return Generation(
                id: generationId,
                userId: userId,
                originalImageUrl: originalImageUrl,
                generatedImageUrl: nil,
                thumbnailUrl: nil,
                styleName: styleName,
                styleCategory: styleCategory,
                stylePrompt: finalPrompt,
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
        print("📤 updateGenerationResult called for: \(generationId)")
        
        guard let userId = supabase.currentUser?.id else {
            print("❌ No user ID available for upload")
            return false
        }
        
        print("   - userId: \(userId)")
        print("   - imageSize: \(generatedImage.size)")
        
        do {
            // 1. Upload generated image
            print("📤 Uploading generated image to Supabase Storage...")
            let generatedImageUrl = try await uploadImage(generatedImage, userId: userId, type: "generated_\(generationId.uuidString)")
            print("   ✅ Generated image URL: \(generatedImageUrl ?? "nil")")
            
            // 2. Create thumbnail
            print("📤 Uploading thumbnail...")
            let thumbnail = generatedImage.preparingThumbnail(of: CGSize(width: 200, height: 200))
            let thumbnailUrl = try await uploadImage(thumbnail ?? generatedImage, userId: userId, type: "thumb_\(generationId.uuidString)")
            print("   ✅ Thumbnail URL: \(thumbnailUrl ?? "nil")")
            
            // 3. Update record
            print("📝 Updating database record...")
            try await supabase.client
                .from("generations")
                .update([
                    "generated_image_url": generatedImageUrl ?? "",
                    "thumbnail_url": thumbnailUrl ?? "",
                    "status": "completed",
                    "processing_time_ms": processingTimeMs,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: generationId.uuidString.lowercased())
                .execute()
            
            print("✅ Generation updated with result successfully!")
            
            // Refresh the list to show updated generation
            await fetchGenerations()
            
            return true
            
        } catch {
            print("❌ UPLOAD ERROR: \(error)")
            print("   Error details: \(error.localizedDescription)")
            
            // Mark as failed
            let _ = try? await supabase.client
                .from("generations")
                .update([
                    "status": "failed",
                    "error_message": error.localizedDescription
                ])
                .eq("id", value: generationId.uuidString.lowercased())
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
                .eq("user_id", value: userId.uuidString.lowercased())
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
    
    // MARK: - Download Authenticated Image (Private Bucket)
    func downloadAuthenticatedImage(path: String) async throws -> UIImage? {
        // If it's a full URL (legacy), try standard download
        if path.hasPrefix("http") {
            return await downloadImage(from: path)
        }
        
        // Otherwise treat as Storage Path and download via API
        print("📥 Downloading secure image from path: \(path)")
        let data = try await supabase.client.storage
            .from(bucketName)
            .download(path: path)
        
        return UIImage(data: data)
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
                .eq("id", value: generationId.uuidString.lowercased())
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
                .eq("id", value: generationId.uuidString.lowercased())
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
        print("   📦 uploadImage starting...")
        print("      - type: \(type)")
        print("      - bucket: \(bucketName)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("   ❌ Failed to convert image to JPEG data")
            return nil
        }
        
        print("      - dataSize: \(imageData.count) bytes")
        
        let fileName = "\(userId.uuidString.lowercased())/\(type)_\(UUID().uuidString.lowercased()).jpg"
        print("      - fileName: \(fileName)")
        
        try await supabase.client.storage
            .from(bucketName)
            .upload(path: fileName, file: imageData, options: .init(contentType: "image/jpeg"))
        
        // 3. Return PATH, not URL (Security: Private Bucket)
        print("   ✅ Upload complete. Path: \(fileName)")
        return fileName
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
