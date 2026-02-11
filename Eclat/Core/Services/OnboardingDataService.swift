//
//  OnboardingDataService.swift
//  Eclat
//
//  Service to save onboarding preferences locally first,
//  then sync to Supabase after user signs in/up
//

import Foundation
import UIKit

// MARK: - Local Storage Keys
private enum StorageKeys {
    static let styleCategory = "onboarding_style_category"
    static let likedStyles = "onboarding_liked_styles"
    static let hasCompletedOnboarding = "has_completed_onboarding"
    static let pendingSync = "onboarding_pending_sync"
    static let capturedImagePath = "onboarding_captured_image_path"
}

// MARK: - Onboarding Data (Local Model)
struct OnboardingData: Codable {
    var styleCategory: String?
    var likedStyles: [String]
    var capturedImagePath: String?
    var completedAt: Date?
    
    static var empty: OnboardingData {
        OnboardingData(styleCategory: nil, likedStyles: [], capturedImagePath: nil, completedAt: nil)
    }
}

// MARK: - Onboarding Data Service
@MainActor
class OnboardingDataService: ObservableObject {
    static let shared = OnboardingDataService()
    
    private let supabase = SupabaseService.shared
    private let defaults = UserDefaults.standard
    
    @Published var localData: OnboardingData = .empty
    @Published var isSyncing = false
    @Published var hasPendingSync = false
    
    init() {
        loadLocalData()
    }
    
    // MARK: - Load Local Data
    private func loadLocalData() {
        if let data = defaults.data(forKey: StorageKeys.pendingSync),
           let decoded = try? JSONDecoder().decode(OnboardingData.self, from: data) {
            localData = decoded
            hasPendingSync = true
        } else {
            // Load individual values
            localData = OnboardingData(
                styleCategory: defaults.string(forKey: StorageKeys.styleCategory),
                likedStyles: defaults.stringArray(forKey: StorageKeys.likedStyles) ?? [],
                capturedImagePath: defaults.string(forKey: StorageKeys.capturedImagePath),
                completedAt: nil
            )
            hasPendingSync = !localData.likedStyles.isEmpty
        }
    }
    
    // MARK: - Save Style Category (Local First)
    func saveStyleCategory(_ category: StyleCategory) {
        localData.styleCategory = category.rawValue.lowercased()
        defaults.set(category.rawValue.lowercased(), forKey: StorageKeys.styleCategory)
        markPendingSync()
        
        print("💾 Style category saved locally: \(category.rawValue)")
    }
    
    // MARK: - Save Liked Styles (Local First)
    func saveLikedStyles(_ styles: [StylePreference]) {
        let styleNames = styles.map { $0.name }
        localData.likedStyles = styleNames
        defaults.set(styleNames, forKey: StorageKeys.likedStyles)
        markPendingSync()
        
        print("💾 Liked styles saved locally: \(styleNames)")
    }
    
    // MARK: - Save Captured Image Path
    func saveCapturedImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileName = "onboarding_selfie_\(UUID().uuidString).jpg"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: path)
            localData.capturedImagePath = path.path
            defaults.set(path.path, forKey: StorageKeys.capturedImagePath)
            markPendingSync()
            print("💾 Captured image saved locally")
            return path.path
        } catch {
            print("❌ Failed to save captured image: \(error)")
            return nil
        }
    }
    
    // MARK: - Mark Onboarding Complete
    func markOnboardingComplete() {
        localData.completedAt = Date()
        defaults.set(true, forKey: StorageKeys.hasCompletedOnboarding)
        markPendingSync()
        
        print("💾 Onboarding marked complete locally")
    }
    
    // MARK: - Mark Pending Sync
    private func markPendingSync() {
        hasPendingSync = true
        if let encoded = try? JSONEncoder().encode(localData) {
            defaults.set(encoded, forKey: StorageKeys.pendingSync)
        }
    }
    
    // MARK: - Sync to Supabase (Called After Login/Signup)
    func syncToSupabase() async {
        guard hasPendingSync else {
            print("ℹ️ No pending sync")
            return
        }
        
        guard let userId = supabase.currentUser?.id else {
            print("⚠️ Cannot sync: User not logged in")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("🔄 Starting sync to Supabase...")
        
        // 1. Sync style category
        if let category = localData.styleCategory {
            do {
                try await supabase.client
                    .from("user_preferences")
                    .upsert([
                        "user_id": userId.uuidString,
                        "style_category": category
                    ])
                    .execute()
                print("✅ Style category synced")
            } catch {
                print("❌ Failed to sync style category: \(error)")
            }
        }
        
        // 2. Sync liked styles
        if !localData.likedStyles.isEmpty, let category = localData.styleCategory {
            let records = localData.likedStyles.map { styleName in
                [
                    "user_id": userId.uuidString,
                    "style_name": styleName,
                    "style_category": category
                ]
            }
            
            do {
                // Delete existing liked styles first
                try await supabase.client
                    .from("liked_styles")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                
                // Insert new ones
                try await supabase.client
                    .from("liked_styles")
                    .insert(records)
                    .execute()
                
                print("✅ Liked styles synced (\(localData.likedStyles.count) styles)")
            } catch {
                print("❌ Failed to sync liked styles: \(error)")
            }
        }
        
        // 3. Track onboarding completed event
        await trackEvent(EventName.onboardingCompleted, data: [
            "style_category": localData.styleCategory ?? "unknown",
            "liked_styles_count": localData.likedStyles.count
        ])
        
        // 4. Clear pending sync
        clearPendingSync()
        
        print("✅ Sync to Supabase complete!")
    }
    
    // MARK: - Clear Pending Sync
    private func clearPendingSync() {
        hasPendingSync = false
        defaults.removeObject(forKey: StorageKeys.pendingSync)
    }
    
    // MARK: - Clear All Local Data
    func clearLocalData() {
        localData = .empty
        defaults.removeObject(forKey: StorageKeys.styleCategory)
        defaults.removeObject(forKey: StorageKeys.likedStyles)
        defaults.removeObject(forKey: StorageKeys.capturedImagePath)
        defaults.removeObject(forKey: StorageKeys.pendingSync)
        defaults.removeObject(forKey: StorageKeys.hasCompletedOnboarding)
        hasPendingSync = false
        
        print("🧹 Local onboarding data cleared")
    }
    
    // MARK: - Track Event (Always tries to sync)
    func trackEvent(_ eventName: String, data: [String: Any] = [:]) async {
        let userId = supabase.currentUser?.id
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        var record: [String: Any] = [
            "event_name": eventName,
            "device_id": deviceId,
            "event_data": data
        ]
        
        if let userId = userId {
            record["user_id"] = userId.uuidString
        }
        
        do {
            try await supabase.client
                .from("onboarding_events")
                .insert([record])
                .execute()
            
            print("📊 Event tracked: \(eventName)")
        } catch {
            print("⚠️ Failed to track event (will retry later): \(error)")
        }
    }
    

    
    func getLikedStyles() -> [String] {
        return localData.likedStyles
    }
    
    func getStyleCategory() -> StyleCategory? {
        guard let local = localData.styleCategory else { return nil }
        // Init from rawValue (capitalized) or simple check
        if local.lowercased() == "men" { return .men }
        if local.lowercased() == "women" { return .women }
        return nil
    }
    
    // MARK: - Check if Completed Onboarding
    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: StorageKeys.hasCompletedOnboarding)
    }
}

// MARK: - Event Names
extension OnboardingDataService {
    enum EventName {
        static let onboardingStarted = "onboarding_started"
        static let styleCategorySelected = "style_category_selected"
        static let styleSwipedLike = "style_swiped_like"
        static let styleSwipedSkip = "style_swiped_skip"
        static let allStylesSwiped = "all_styles_swiped"
        static let selfieTaken = "selfie_taken"
        static let paywallShown = "paywall_shown"
        static let subscriptionStarted = "subscription_started"
        static let onboardingCompleted = "onboarding_completed"
    }
}
