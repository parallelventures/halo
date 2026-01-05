//
//  SupabaseService.swift
//  Halo
//
//  Supabase integration for storage and user history
//

import Foundation
import UIKit

// MARK: - Supabase Auth Helper
struct SupabaseAuth {
    static var currentUserId: String? {
        // Use authenticated user ID if available (stored in UserDefaults by AuthService)
        if let userId = UserDefaults.standard.string(forKey: "supabase_user_id"), !userId.isEmpty {
            return userId
        }
        
        // Fallback to anonymous ID for users who didn't sign in
        if let stored = UserDefaults.standard.string(forKey: "halo_anonymous_id") {
            return stored
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "halo_anonymous_id")
        return newId
    }
    
    static var accessToken: String? {
        UserDefaults.standard.string(forKey: "supabase_access_token")
    }
}

// MARK: - Hairstyle Generation Model
struct HairstyleGeneration: Identifiable, Codable {
    let id: String
    let userId: String
    let styleName: String
    let styleCategory: String?
    let imagePath: String
    let createdAt: Date
    
    // Signed URL for private bucket access (set after fetch)
    var signedImageURL: URL?
    
    var imageURL: URL? {
        // Use signed URL if available, otherwise fallback to public URL
        signedImageURL ?? URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/public/hairstyles/\(imagePath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case styleName = "style_name"
        case styleCategory = "style_category"
        case imagePath = "image_path"
        case createdAt = "created_at"
        // signedImageURL is not in JSON, computed after fetch
    }
}

// MARK: - Supabase Storage Service
final class SupabaseStorageService: ObservableObject {
    
    static let shared = SupabaseStorageService()
    
    @Published var generations: [HairstyleGeneration] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let session: URLSession
    private let bucketName = "hairstyles"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Save Generated Image
    func saveGeneration(image: UIImage, styleName: String, category: String?) async throws -> HairstyleGeneration {
        guard let userId = SupabaseAuth.currentUserId else {
            throw StorageError.notAuthenticated
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidImage
        }
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        let path = "\(userId)/\(filename)"
        
        // Upload to storage
        try await uploadImage(data: imageData, path: path)
        
        // Save metadata to database
        var generation = try await saveMetadata(
            userId: userId,
            styleName: styleName,
            category: category,
            imagePath: path
        )
        
        // Generate signed URL for the new generation
        do {
            let signedURL = try await getSignedURL(for: path)
            generation.signedImageURL = signedURL
        } catch {
            print("⚠️ Failed to get signed URL for new generation: \(error)")
        }
        
        // Update local list
        await MainActor.run {
            self.generations.insert(generation, at: 0)
        }
        
        return generation
    }
    
    // MARK: - Upload Image
    private func uploadImage(data: Data, path: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/\(bucketName)/\(path)")!
        
        // Use user's access token if available, otherwise anon key
        let authToken = SupabaseAuth.accessToken ?? SupabaseConfig.anonKey
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.uploadFailed
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            print("❌ Upload failed (\(httpResponse.statusCode)): \(errorMsg)")
            throw StorageError.uploadFailed
        }
        
        print("✅ Image uploaded successfully to: \(path)")
    }
    
    // MARK: - Save Metadata
    private func saveMetadata(userId: String, styleName: String, category: String?, imagePath: String) async throws -> HairstyleGeneration {
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/hairstyle_generations")!
        
        let id = UUID().uuidString
        let now = Date()
        
        let body: [String: Any] = [
            "id": id,
            "user_id": userId,
            "style_name": styleName,
            "style_category": category ?? "",
            "image_path": imagePath
        ]
        
        // Use user's access token if available
        let authToken = SupabaseAuth.accessToken ?? SupabaseConfig.anonKey
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.saveFailed
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            print("❌ Save metadata failed (\(httpResponse.statusCode)): \(errorMsg)")
            throw StorageError.saveFailed
        }
        
        print("✅ Metadata saved for: \(styleName)")
        
        return HairstyleGeneration(
            id: id,
            userId: userId,
            styleName: styleName,
            styleCategory: category,
            imagePath: imagePath,
            createdAt: now
        )
    }
    
    // MARK: - Fetch User History
    func fetchHistory() async {
        guard let userId = SupabaseAuth.currentUserId else {
            print("❌ No user ID for history fetch")
            return
        }
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        let urlString = "\(SupabaseConfig.projectURL)/rest/v1/hairstyle_generations?user_id=eq.\(userId)&order=created_at.desc"
        guard let url = URL(string: urlString) else { return }
        
        // Use user's access token if available
        let authToken = SupabaseAuth.accessToken ?? SupabaseConfig.anonKey
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 History fetch status: \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var items = try decoder.decode([HairstyleGeneration].self, from: data)
            print("✅ Fetched \(items.count) generations")
            
            // Generate signed URLs for private bucket access
            for i in 0..<items.count {
                do {
                    let signedURL = try await getSignedURL(for: items[i].imagePath)
                    items[i].signedImageURL = signedURL
                } catch {
                    print("⚠️ Failed to get signed URL for \(items[i].imagePath): \(error)")
                }
            }
            
            await MainActor.run {
                self.generations = items
            }
        } catch {
            print("❌ Fetch history error: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Get Signed URL for Image
    func getSignedURL(for path: String) async throws -> URL {
        let urlString = "\(SupabaseConfig.projectURL)/storage/v1/object/sign/\(bucketName)/\(path)"
        guard let url = URL(string: urlString) else {
            throw StorageError.invalidPath
        }
        
        let body = ["expiresIn": 3600] // 1 hour
        
        // Use user's access token for private bucket access
        let authToken = SupabaseAuth.accessToken ?? SupabaseConfig.anonKey
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📝 Signed URL response status: \(httpResponse.statusCode)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📝 Signed URL response: \(responseString)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let signedPath = json["signedURL"] as? String else {
            print("❌ Failed to parse signed URL response")
            throw StorageError.signFailed
        }
        
        let signedURL = URL(string: "\(SupabaseConfig.projectURL)/storage/v1\(signedPath)")!
        print("✅ Generated signed URL: \(signedURL)")
        
        return signedURL
    }
    
    // MARK: - Delete Generation
    func deleteGeneration(_ generation: HairstyleGeneration) async throws {
        // Delete from storage
        let storageURL = URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/\(bucketName)/\(generation.imagePath)")!
        
        var storageRequest = URLRequest(url: storageURL)
        storageRequest.httpMethod = "DELETE"
        storageRequest.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        storageRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        _ = try await session.data(for: storageRequest)
        
        // Delete from database
        let dbURL = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/hairstyle_generations?id=eq.\(generation.id)")!
        
        var dbRequest = URLRequest(url: dbURL)
        dbRequest.httpMethod = "DELETE"
        dbRequest.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        dbRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        _ = try await session.data(for: dbRequest)
        
        // Update local list
        await MainActor.run {
            self.generations.removeAll { $0.id == generation.id }
        }
    }
}

// MARK: - Storage Errors
enum StorageError: LocalizedError {
    case notAuthenticated
    case invalidImage
    case uploadFailed
    case saveFailed
    case invalidPath
    case signFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidImage:
            return "Invalid image"
        case .uploadFailed:
            return "Failed to upload image"
        case .saveFailed:
            return "Failed to save"
        case .invalidPath:
            return "Invalid path"
        case .signFailed:
            return "Failed to sign URL"
        }
    }
}
