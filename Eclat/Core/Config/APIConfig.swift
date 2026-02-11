//
//  APIConfig.swift
//  Eclat
//
//  Centralized API configuration management
//

import Foundation

// MARK: - Environment
enum AppEnvironment {
    case development
    case staging
    case production
    
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

// MARK: - API Configuration
enum APIConfig {
    
    // MARK: - Base URLs
    static var baseURL: String {
        switch AppEnvironment.current {
        case .development, .staging:
            return "https://generativelanguage.googleapis.com/v1beta"
        case .production:
            return "https://generativelanguage.googleapis.com/v1beta"
        }
    }
    
    // MARK: - API Keys
    // ⚠️ IMPORTANT: In production, use a secure method to store API keys
    // Options:
    // 1. Keychain
    // 2. Server-side proxy
    // 3. Obfuscation + runtime decryption
    // 4. Firebase Remote Config
    
    static var geminiAPIKey: String {
        // Try to get from environment variable first (for CI/CD)
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Try to get from Info.plist
        if let plistKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String, !plistKey.isEmpty {
            return plistKey
        }
        
        // Fallback to hardcoded key (replace with your key for development)
        // ⚠️ Never commit real API keys to version control!
        return "YOUR_GEMINI_API_KEY_HERE"
    }
    
    // MARK: - Timeout Configuration
    static var defaultTimeout: TimeInterval { 60 }
    static var imageGenerationTimeout: TimeInterval { 120 }
    
    // MARK: - Rate Limiting
    static var maxRequestsPerMinute: Int { 10 }
    
    // MARK: - Image Configuration
    static var maxImageSize: CGSize { CGSize(width: 1024, height: 1024) }
    static var imageCompressionQuality: CGFloat { 0.8 }
}

// MARK: - Feature Flags
enum FeatureFlags {
    
    // Remote config (integrate with Firebase Remote Config in production)
    private static var remoteConfig: [String: Any] = [:]
    
    // MARK: - Flags
    static var isDebugModeEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var showOnboarding: Bool {
        remoteConfig["show_onboarding"] as? Bool ?? true
    }
    
    static var enableHaptics: Bool {
        remoteConfig["enable_haptics"] as? Bool ?? true
    }
    
    static var enableAnalytics: Bool {
        remoteConfig["enable_analytics"] as? Bool ?? true
    }
    
    static var paywallVariant: String {
        remoteConfig["paywall_variant"] as? String ?? "A"
    }
}

// MARK: - App Constants
enum AppConstants {
    static let appName = "Eclat"
    static let appStoreID = "YOUR_APP_STORE_ID"
    static let supportEmail = "support@eclatapp.com"
    static let privacyPolicyURL = URL(string: "https://eclatapp.com/privacy")!
    static let termsOfServiceURL = URL(string: "https://eclatapp.com/terms")!
}
