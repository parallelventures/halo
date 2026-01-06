//
//  SupabaseService.swift
//  Halo
//
//  Custom light-weight Supabase Client
//

import Foundation
import UIKit

// MARK: - Main Service
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient()
    }
    
    var currentUser: User? {
        SupabaseAuth.currentUser
    }
}

// MARK: - Models
struct User {
    let id: UUID
    let email: String?
}

// MARK: - Client Wrapper
class SupabaseClient {
    let storage: SupabaseStorageClient
    
    init() {
        self.storage = SupabaseStorageClient()
    }
    
    func from(_ table: String) -> SupabaseQueryBuilder {
        SupabaseQueryBuilder(table: table)
    }
}

// MARK: - DB Query Builder
class SupabaseQueryBuilder {
    let table: String
    private var method: String = "GET"
    private var body: Data?
    private var queryParams: [String] = []
    private var headers: [String: String] = [:]
    
    init(table: String) {
        self.table = table
    }
    
    // MARK: Operations
    func select(_ columns: String = "*") -> SupabaseQueryBuilder {
        method = "GET"
        queryParams.append("select=\(columns)")
        return self
    }
    
    func insert(_ values: [String: Any]) -> SupabaseQueryBuilder {
        return insert([values])
    }
    
    func insert(_ values: [[String: Any]]) -> SupabaseQueryBuilder {
        method = "POST"
        headers["Prefer"] = "return=representation"
        if let data = try? JSONSerialization.data(withJSONObject: values) {
            body = data
        }
        return self
    }
    

    
    func upsert(_ values: [String: Any]) -> SupabaseQueryBuilder {
        method = "POST"
        headers["Prefer"] = "resolution=merge-duplicates,return=representation"
        if let data = try? JSONSerialization.data(withJSONObject: values) {
            body = data
        }
        return self
    }
    
    func update(_ values: [String: Any]) -> SupabaseQueryBuilder {
        method = "PATCH"
        headers["Prefer"] = "return=representation"
        if let data = try? JSONSerialization.data(withJSONObject: values) {
            body = data
        }
        return self
    }
    
    func delete() -> SupabaseQueryBuilder {
        method = "DELETE"
        headers["Prefer"] = "return=representation"
        return self
    }
    
    // MARK: Filters
    func eq(_ column: String, value: String) -> SupabaseQueryBuilder {
        queryParams.append("\(column)=eq.\(value)")
        return self
    }
    
    func eq(_ column: String, value: Bool) -> SupabaseQueryBuilder {
        queryParams.append("\(column)=eq.\(value)")
        return self
    }
    
    func eq(_ column: String, value: Int) -> SupabaseQueryBuilder {
         queryParams.append("\(column)=eq.\(value)")
         return self
    }
    
    func order(_ column: String, ascending: Bool = true) -> SupabaseQueryBuilder {
        queryParams.append("order=\(column).\(ascending ? "asc" : "desc")")
        return self
    }
    
    func single() -> SupabaseQueryBuilder {
        headers["Accept"] = "application/vnd.pgrst.object+json"
        return self
    }
    
    // MARK: Execute
    @discardableResult
    func execute() async throws -> PostgrestResponse {
        var urlString = "\(SupabaseConfig.projectURL)/rest/v1/\(table)"
        if !queryParams.isEmpty {
            urlString += "?" + queryParams.joined(separator: "&")
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Headers
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Auth
        if let token = SupabaseAuth.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            // let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            // print("❌ Supabase Error (\(httpResponse.statusCode)): \(errorMsg)")
            throw URLError(.badServerResponse)
        }
        
        return PostgrestResponse(data: data, status: httpResponse.statusCode)
    }
}

struct PostgrestResponse {
    let data: Data
    let status: Int
}

// MARK: - Storage Client
class SupabaseStorageClient {
    func from(_ bucket: String) -> SupabaseStorageBucket {
        SupabaseStorageBucket(bucket: bucket)
    }
}

class SupabaseStorageBucket {
    let bucket: String
    
    init(bucket: String) {
        self.bucket = bucket
    }
    
    func upload(path: String, file: Data, options: FileOptions) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/\(bucket)/\(path)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Auth
        if let token = SupabaseAuth.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue(options.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = file
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             throw URLError(.badServerResponse)
        }
    }
    
    func getPublicURL(path: String) -> URL {
        return URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/public/\(bucket)/\(path)")!
    }
}

struct FileOptions {
    var contentType: String = "application/octet-stream"
}

// MARK: - Auth Helper
struct SupabaseAuth {
    static var currentUserId: String? {
        // Use authenticated user ID if available
        if let userId = UserDefaults.standard.string(forKey: "supabase_user_id"), !userId.isEmpty {
            return userId
        }
        return nil
    }
    
    static var currentUser: User? {
        guard let idString = currentUserId, let uuid = UUID(uuidString: idString) else { return nil }
        return User(id: uuid, email: nil)
    }
    
    static var accessToken: String? {
        UserDefaults.standard.string(forKey: "supabase_access_token")
    }
}
