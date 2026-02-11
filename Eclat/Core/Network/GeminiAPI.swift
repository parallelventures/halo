//
//  GeminiAPI.swift
//  Eclat
//
//  Gemini API integration via Supabase Edge Function (secure proxy)
//

import Foundation
import UIKit

// MARK: - Supabase Configuration
enum SupabaseConfig {
    static let projectURL = "https://noqpxmaipkhsresxyupl.supabase.co"
    
    // Supabase anon key (safe to include in app - it's public)
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vcXB4bWFpcGtoc3Jlc3h5dXBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0NjI4MjIsImV4cCI6MjA4MzAzODgyMn0.AgHtUmBBBfB8992P2t6RQ1MtkUvuDm3XaRqxqVwlzk8"
    
    // Edge function endpoint
    static var generateHairstyleURL: URL {
        URL(string: "\(projectURL)/functions/v1/generate-hairstyle")!
    }
}

// MARK: - Edge Function Request/Response
struct EdgeFunctionRequest: Encodable {
    let image: String  // Base64 encoded
    let prompt: String
}

struct EdgeFunctionResponse: Decodable {
    let success: Bool?
    let image: String?
    let mimeType: String?
    let error: String?
    let details: String?
}

// MARK: - Gemini API Error
enum GeminiError: LocalizedError {
    case invalidImage
    case noImageGenerated
    case contentBlocked(reason: String)
    case serverError(String)
    case networkError(Error)
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .noImageGenerated:
            return "No image was generated"
        case .contentBlocked(let reason):
            return "Content blocked: \(reason)"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        case .configurationError:
            return "Server is not configured correctly"
        }
    }
}

// MARK: - Gemini API Service Protocol
protocol GeminiAPIServiceProtocol {
    func generateHairstyle(from image: UIImage, prompt: String) async throws -> UIImage
}

// MARK: - Gemini API Service (via Supabase Edge Function)
final class GeminiAPIService: GeminiAPIServiceProtocol {
    
    // MARK: - Singleton
    static let shared = GeminiAPIService()
    
    // MARK: - Properties
    private let session: URLSession
    
    // MARK: - Init
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generate Hairstyle
    func generateHairstyle(from image: UIImage, prompt: String) async throws -> UIImage {
        // Compress and convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Build request body
        let requestBody = EdgeFunctionRequest(image: base64Image, prompt: prompt)
        
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(requestBody)
        } catch {
            throw GeminiError.networkError(error)
        }
        
        // Build URL request
        var request = URLRequest(url: SupabaseConfig.generateHairstyleURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        // 🚨 CRITICAL FIX: Ensure we have a valid access token before making the request
        var accessToken = SupabaseAuth.accessToken
        
        // Debug: Log current auth state
        print("🔐 GeminiAPI Auth Debug:")
        print("   - Initial accessToken: \(accessToken != nil ? "✅ Present" : "❌ nil")")
        print("   - SupabaseAuth.currentUserId: \(SupabaseAuth.currentUserId ?? "nil")")
        
        // If no token, try to refresh the session first
        if accessToken == nil {
            print("⚠️ No access token found - attempting to refresh session...")
            let refreshed = await AuthService.shared.refreshSession()
            if refreshed {
                accessToken = SupabaseAuth.accessToken
                print("✅ Session refreshed successfully, token: \(accessToken != nil ? "Present" : "Still nil!")")
            } else {
                print("❌ Session refresh failed")
            }
        }
        
        // Set Authorization header
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 Authenticated request with User Token")
            // Debug: Log token structure (first 50 chars + parts count)
            let parts = token.split(separator: ".")
            print("   - Token parts: \(parts.count) (should be 3)")
            print("   - Token prefix: \(String(token.prefix(50)))...")
        } else {
            // No token available - cannot proceed without authentication
            print("❌ No user session available - cannot generate hairstyle")
            print("   👉 User needs to sign in with Apple/Google first")
            throw GeminiError.serverError("Please sign in to generate hairstyles")
        }
        
        request.httpBody = bodyData
        
        // Execute request
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.serverError("Invalid response")
        }
        
        // 🚨 DEBUG: Log full response details
        print("📡 GeminiAPI Response:")
        print("   - Status Code: \(httpResponse.statusCode)")
        if let responseBody = String(data: data, encoding: .utf8) {
            print("   - Body: \(responseBody.prefix(500))...")
        }
        
        // Check for HTTP errors first
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ GeminiAPI HTTP Error \(httpResponse.statusCode): \(errorBody)")
            throw GeminiError.serverError("Server error (\(httpResponse.statusCode)): \(errorBody)")
        }
        
        // Parse response
        let edgeResponse: EdgeFunctionResponse
        do {
            edgeResponse = try JSONDecoder().decode(EdgeFunctionResponse.self, from: data)
        } catch {
            // Try to get error message from raw response
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("❌ Failed to decode response: \(errorMessage)")
                throw GeminiError.serverError(errorMessage)
            }
            throw GeminiError.networkError(error)
        }
        
        // Check for errors in response body
        if let error = edgeResponse.error {
            print("❌ Edge Function returned error: \(error)")
            if httpResponse.statusCode == 500 && error == "Server configuration error" {
                throw GeminiError.configurationError
            }
            throw GeminiError.serverError(error)
        }
        
        // Extract image
        guard edgeResponse.success == true,
              let imageBase64 = edgeResponse.image,
              let imageData = Data(base64Encoded: imageBase64),
              let generatedImage = UIImage(data: imageData) else {
            throw GeminiError.noImageGenerated
        }
        
        return generatedImage
    }
}

// MARK: - Mock Service for Previews
#if DEBUG
final class MockGeminiAPIService: GeminiAPIServiceProtocol {
    
    var shouldFail = false
    var delay: TimeInterval = 2.0
    
    func generateHairstyle(from image: UIImage, prompt: String) async throws -> UIImage {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldFail {
            throw GeminiError.noImageGenerated
        }
        
        // Return the same image (for demo)
        return image
    }
}
#endif
