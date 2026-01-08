//
//  TikTokService.swift
//  Halo
//
//  TikTok Business SDK wrapper for analytics and attribution
//

import Foundation
import AppTrackingTransparency
import TikTokBusinessSDK

final class TikTokService {
    
    static let shared = TikTokService()
    
    // MARK: - Configuration (TikTok for Business credentials)
    private let appID = "6757233043"
    private let tiktokAppID = "7592938947324428295"
    private let accessToken = "TTD81RZ8gx2COTOUqzs2rgoHBLF65toD"
    
    private var isInitialized = false
    
    private init() {}
    
    // MARK: - Initialize SDK
    /// Call this in your App's init or didFinishLaunching
    func configure() {
        guard !isInitialized else { return }
        
        let config = TikTokConfig(accessToken: accessToken, appId: appID, tiktokAppId: tiktokAppID)
        
        if let config = config {
            TikTokBusiness.initializeSdk(config)
            isInitialized = true
            print("✅ TikTok SDK initialized")
        }
    }
    
    // MARK: - Request Tracking Permission (ATT)
    /// Request App Tracking Transparency authorization
    func requestTrackingPermission() async -> ATTrackingManager.AuthorizationStatus {
        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    // MARK: - User Identification
    /// Identify user when they log in (Apple/Google Sign-In)
    func identifyUser(userId: String, email: String? = nil) {
        TikTokBusiness.identify(
            withExternalID: userId,
            externalUserName: nil,
            phoneNumber: nil,
            email: email
        )
        print("✅ TikTok: User identified - \(userId)")
    }
    
    // MARK: - Helper to create TikTok events
    private func trackTTEvent(_ eventName: String, properties: [String: Any]? = nil) {
        let event = TikTokBaseEvent(eventName: eventName)
        if let properties = properties {
            for (key, value) in properties {
                event.addProperty(withKey: key, value: value)
            }
        }
        TikTokBusiness.trackTTEvent(event)
    }
    
    // MARK: - Core App Events
    
    /// Track app launch
    func trackAppLaunch() {
        trackTTEvent("LaunchAPP")
        print("📊 TikTok: App Launch tracked")
    }
    
    /// Track user registration (completed sign-up)
    func trackRegistration(method: String) {
        trackTTEvent("Registration", properties: [
            "registration_method": method
        ])
        print("📊 TikTok: Registration tracked - \(method)")
    }
    
    /// Track user login
    func trackLogin(method: String) {
        trackTTEvent("Login", properties: [
            "login_method": method
        ])
        print("📊 TikTok: Login tracked - \(method)")
    }
    
    /// Track onboarding completion
    func trackCompleteTutorial() {
        trackTTEvent("CompleteTutorial")
        print("📊 TikTok: Complete Tutorial tracked")
    }
    
    // MARK: - Content Events
    
    /// Track viewing a hairstyle
    func trackViewHairstyle(styleId: String, styleName: String, category: String) {
        trackTTEvent("ViewContent", properties: [
            "content_id": styleId,
            "content_name": styleName,
            "content_type": "hairstyle",
            "category": category
        ])
        print("📊 TikTok: View Content tracked - \(styleName)")
    }
    
    /// Track hairstyle generation completed
    func trackGenerationComplete(styleId: String, styleName: String) {
        trackTTEvent("UnlockAchievement", properties: [
            "achievement_type": "hairstyle_generated",
            "style_id": styleId,
            "style_name": styleName
        ])
        print("📊 TikTok: Generation Complete tracked - \(styleName)")
    }
    
    // MARK: - Subscription Events
    
    /// Track start trial (if applicable)
    func trackStartTrial() {
        trackTTEvent("StartTrial")
        print("📊 TikTok: Start Trial tracked")
    }
    
    /// Track subscription started
    func trackSubscribe(planType: String, price: Double, currency: String = "USD") {
        trackTTEvent("Subscribe", properties: [
            "plan_type": planType,
            "value": price,
            "currency": currency
        ])
        print("📊 TikTok: Subscribe tracked - \(planType) $\(price)")
    }
    
    /// Track purchase completed (subscription or one-time)
    func trackPurchase(productId: String, productName: String, price: Double, currency: String = "USD") {
        trackTTEvent("Purchase", properties: [
            "content_id": productId,
            "content_name": productName,
            "value": price,
            "currency": currency,
            "content_type": "subscription"
        ])
        print("📊 TikTok: Purchase tracked - \(productName) $\(price)")
    }
    
    /// Track checkout initiated (paywall opened)
    func trackCheckoutInitiated(planType: String, price: Double) {
        trackTTEvent("InitiateCheckout", properties: [
            "content_id": planType,
            "value": price,
            "currency": "USD",
            "content_type": "subscription"
        ])
        print("📊 TikTok: Checkout tracked - \(planType)")
    }
    
    /// Track add payment info
    func trackAddPaymentInfo() {
        trackTTEvent("AddPaymentInfo")
        print("📊 TikTok: Add Payment Info tracked")
    }
    
    // MARK: - Engagement Events
    
    /// Track level achieved (e.g., number of generations)
    func trackAchieveLevel(level: Int) {
        trackTTEvent("AchieveLevel", properties: [
            "level": level
        ])
        print("📊 TikTok: Achieve Level tracked - Level \(level)")
    }
    
    /// Track search (style search if implemented)
    func trackSearch(query: String) {
        trackTTEvent("Search", properties: [
            "search_string": query
        ])
        print("📊 TikTok: Search tracked - \(query)")
    }
    
    /// Track rate app
    func trackRate() {
        trackTTEvent("Rate", properties: [
            "lead_type": "app_rating"
        ])
        print("📊 TikTok: Rate tracked")
    }
    
    /// Track share content
    func trackShare(contentType: String, contentId: String) {
        trackTTEvent("Share", properties: [
            "content_type": contentType,
            "content_id": contentId
        ])
        print("📊 TikTok: Share tracked - \(contentType)")
    }
    
    /// Track download image
    func trackDownload(contentId: String) {
        trackTTEvent("Download", properties: [
            "content_id": contentId,
            "content_type": "hairstyle_image"
        ])
        print("📊 TikTok: Download tracked")
    }
    
    // MARK: - Custom Events
    
    /// Track camera opened
    func trackCameraOpened() {
        trackTTEvent("CameraOpened")
        print("📊 TikTok: Camera Opened tracked")
    }
    
    /// Track selfie captured
    func trackSelfieCaptured() {
        trackTTEvent("SelfieCaptured")
        print("📊 TikTok: Selfie Captured tracked")
    }
    
    /// Track style selected
    func trackStyleSelected(styleId: String, styleName: String, category: String) {
        trackTTEvent("StyleSelected", properties: [
            "style_id": styleId,
            "style_name": styleName,
            "category": category
        ])
        print("📊 TikTok: Style Selected tracked - \(styleName)")
    }
    
    /// Track paywall viewed
    func trackPaywallViewed(source: String) {
        trackTTEvent("PaywallViewed", properties: [
            "source": source
        ])
        print("📊 TikTok: Paywall Viewed tracked - from \(source)")
    }
    
    /// Track paywall dismissed
    func trackPaywallDismissed(selectedPlan: String?) {
        var properties: [String: Any] = [:]
        if let plan = selectedPlan {
            properties["selected_plan"] = plan
        }
        trackTTEvent("PaywallDismissed", properties: properties.isEmpty ? nil : properties)
        print("📊 TikTok: Paywall Dismissed tracked")
    }
}
