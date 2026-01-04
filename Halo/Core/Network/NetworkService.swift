//
//  NetworkService.swift
//  Halo
//
//  Base networking layer with async/await
//

import Foundation

// MARK: - Network Error
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case httpError(statusCode: Int)
    case decodingError(Error)
    case encodingError(Error)
    case noInternet
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidData:
            return "Invalid data received"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .noInternet:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Network Request
struct NetworkRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let timeoutInterval: TimeInterval
    
    init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 60
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
    }
}

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    func execute(_ request: NetworkRequest) async throws -> Data
    func execute<T: Decodable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T
}

// MARK: - Network Service
final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Singleton
    static let shared = NetworkService()
    
    // MARK: - Properties
    private let session: URLSession
    private let decoder: JSONDecoder
    
    // MARK: - Init
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - Execute Request
    func execute(_ request: NetworkRequest) async throws -> Data {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeoutInterval
        
        // Add headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body
        if let body = request.body {
            urlRequest.httpBody = body
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                throw NetworkError.noInternet
            } else if (error as NSError).code == NSURLErrorTimedOut {
                throw NetworkError.timeout
            }
            throw NetworkError.unknown(error)
        }
    }
    
    func execute<T: Decodable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        let data = try await execute(request)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
