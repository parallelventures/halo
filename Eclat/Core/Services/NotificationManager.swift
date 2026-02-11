//
//  NotificationManager.swift
//  Eclat
//
//  Top-tier segment-based push notification system
//  Premium tone, no spam, CVR + retention focused
//

import UserNotifications
import UIKit

// MARK: - Notification Key
enum NotificationKey: String {
    // Tourist (no purchase)
    case tourist_t6 = "tourist_t6"           // 6h after install
    case tourist_t24 = "tourist_t24"         // 24h after install
    case tourist_t48 = "tourist_t48"         // 48h after install
    
    // Sampler (entry paid or 3-6 looks)
    case sampler_first_result = "sampler_first_result"   // 3h after first result
    case sampler_next_day = "sampler_next_day"           // Next day 19:00
    case sampler_t48_purchase = "sampler_t48_purchase"   // 48h after entry
    
    // Explorer (high intent)
    case explorer_evening = "explorer_evening"           // 20:00 same day
    case explorer_next_day = "explorer_next_day"         // 18:00 next day
    case explorer_weekly = "explorer_weekly"             // 1x per week
    
    // Buyer
    case buyer_post_purchase = "buyer_post_purchase"     // After pack purchase
    case buyer_t24_purchase = "buyer_t24_purchase"       // 24h after pack
    case buyer_low_looks = "buyer_low_looks"             // When balance hits 2
    
    // Creator Mode
    case creator_day1 = "creator_day1"                   // Day 1 of sub
    case creator_day5 = "creator_day5"                   // Day 5 pre-renewal
    
    // Churn risk
    case churn_48h = "churn_48h"                         // 48h inactive
    case churn_7d = "churn_7d"                           // 7d inactive
    
    // Power/Whale
    case power_monthly = "power_monthly"                 // 1x per month
}

// MARK: - Copy Variants
struct NotificationCopy {
    let bodyA: String
    let bodyB: String
    let deepLink: String
    
    var randomBody: String {
        Bool.random() ? bodyA : bodyB
    }
}

// MARK: - Notification Manager
@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    
    // MARK: - Copy Library (Premium, No Emoji)
    private let copyLibrary: [NotificationKey: NotificationCopy] = [
        // Tourist
        .tourist_t6: NotificationCopy(
            bodyA: "See your next hairstyle on you.",
            bodyB: "Try one look — it takes seconds.",
            deepLink: "eclat://home"
        ),
        .tourist_t24: NotificationCopy(
            bodyA: "Still deciding? Preview it first.",
            bodyB: "See yourself differently today.",
            deepLink: "eclat://home"
        ),
        .tourist_t48: NotificationCopy(
            bodyA: "Curious what bangs would look like?",
            bodyB: "Try a new look before you commit.",
            deepLink: "eclat://home"
        ),
        
        // Sampler
        .sampler_first_result: NotificationCopy(
            bodyA: "Try 2 more looks before you decide.",
            bodyB: "One more look can change the decision.",
            deepLink: "eclat://home"
        ),
        .sampler_next_day: NotificationCopy(
            bodyA: "Your next look is waiting.",
            bodyB: "Continue where you left off.",
            deepLink: "eclat://home"
        ),
        .sampler_t48_purchase: NotificationCopy(
            bodyA: "Your looks are saved — revisit them anytime.",
            bodyB: "Compare your looks again — it's clearer the second time.",
            deepLink: "eclat://history"
        ),
        
        // Explorer
        .explorer_evening: NotificationCopy(
            bodyA: "Try one more version tonight.",
            bodyB: "Explore a new style while it's fresh.",
            deepLink: "eclat://home"
        ),
        .explorer_next_day: NotificationCopy(
            bodyA: "Try this style on you.",
            bodyB: "This look might suit your face shape.",
            deepLink: "eclat://home"
        ),
        .explorer_weekly: NotificationCopy(
            bodyA: "New looks are trending right now.",
            bodyB: "A new version of you is one tap away.",
            deepLink: "eclat://home"
        ),
        
        // Buyer
        .buyer_post_purchase: NotificationCopy(
            bodyA: "You're back in flow.",
            bodyB: "You're back in flow.",
            deepLink: "eclat://home"
        ),
        .buyer_t24_purchase: NotificationCopy(
            bodyA: "Use your looks while your decision is fresh.",
            bodyB: "Try a few more — you're close to the best one.",
            deepLink: "eclat://home"
        ),
        .buyer_low_looks: NotificationCopy(
            bodyA: "A few looks left.",
            bodyB: "Keep exploring without interruptions.",
            deepLink: "eclat://home"
        ),
        
        // Creator Mode
        .creator_day1: NotificationCopy(
            bodyA: "Creator Mode is on — try a new look.",
            bodyB: "Your studio is ready whenever you are.",
            deepLink: "eclat://home"
        ),
        .creator_day5: NotificationCopy(
            bodyA: "Use Creator Mode before the week ends.",
            bodyB: "Create a few looks today — it's worth it.",
            deepLink: "eclat://home"
        ),
        
        // Churn
        .churn_48h: NotificationCopy(
            bodyA: "See yourself differently today.",
            bodyB: "Your next look takes seconds.",
            deepLink: "eclat://home"
        ),
        .churn_7d: NotificationCopy(
            bodyA: "Revisit your looks — you might see it differently now.",
            bodyB: "Want to try a completely new direction?",
            deepLink: "eclat://history"
        ),
        
        // Power
        .power_monthly: NotificationCopy(
            bodyA: "Thank you for being here.",
            bodyB: "Your studio is always open.",
            deepLink: "eclat://home"
        )
    ]
    
    // MARK: - Caps & Cooldowns
    private let maxPushPerDay: Int = 1
    private let maxPushPerWeek: Int = 3
    private let cooldownHours: Int = 18
    private let quietHourStart: Int = 22  // 10 PM
    private let quietHourEnd: Int = 9     // 9 AM
    
    // MARK: - Last Session Tracking
    private var lastSessionTime: Date {
        get { UserDefaults.standard.object(forKey: "last_session_time") as? Date ?? Date() }
        set { UserDefaults.standard.set(newValue, forKey: "last_session_time") }
    }
    
    // MARK: - Request Permission (After Win Moment)
    /// Check if we should show the pre-permission prompt
    func shouldShowPermissionPrompt() -> Bool {
        return NotificationPermissionManager.shared.canShowPrompt
    }
    
    /// Old method - deprecated, use PushPermissionView instead
    func requestPermission(afterWinMoment: Bool = true) {
        // Check eligibility first
        guard afterWinMoment, NotificationPermissionManager.shared.canShowPrompt else { return }
        
        // This will be replaced by showing PushPermissionView
        // For backward compatibility, still request directly
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("🔔 Push notifications granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    NotificationPermissionManager.shared.markAsAsked(allowed: true)
                    self.scheduleSmartNotifications()
                }
            } else if let error = error {
                print("🔕 Push permission error: \(error)")
                NotificationPermissionManager.shared.markAsAsked(allowed: false)
            }
        }
    }
    
    // MARK: - Schedule Smart Notifications (Reset on App Open)
    func scheduleSmartNotifications() {
        // Record session for "30 min after session" rule
        lastSessionTime = Date()
        
        // Clear all pending (reset the clock)
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        print("⏰ Scheduling segment-based notifications...")
        
        // Get user segment
        let segment = MonetizationEngine.shared.currentSegment
        let isSubscribed = SubscriptionManager.shared.isSubscribed
        let looksRemaining = SubscriptionManager.shared.weeklyLooksRemaining
        
        // Schedule based on segment
        switch segment {
        case .tourist:
            if !isSubscribed {
                scheduleNotification(.tourist_t24, delay: 24 * 60 * 60)
                scheduleNotification(.tourist_t48, delay: 48 * 60 * 60)
            }
            
        case .sampler:
            scheduleEveningNotification(.sampler_next_day, hour: 19, minute: 0)
            if isSubscribed {
                scheduleNotification(.sampler_t48_purchase, delay: 48 * 60 * 60)
            }
            
        case .explorer:
            scheduleEveningNotification(.explorer_evening, hour: 20, minute: 0)
            
        case .buyer:
            if looksRemaining <= 3 && looksRemaining > 0 {
                scheduleNotification(.buyer_low_looks, delay: 24 * 60 * 60)
            }
            
        case .power:
            // Minimal - only 1x per month
            break
        }
        
        // Churn prevention (always schedule)
        scheduleNotification(.churn_48h, delay: 48 * 60 * 60)
        scheduleNotification(.churn_7d, delay: 7 * 24 * 60 * 60)
    }
    
    // MARK: - Schedule After First Result (Delight Moment)
    func scheduleAfterFirstResult() {
        let segment = MonetizationEngine.shared.currentSegment
        
        if segment == .sampler || segment == .tourist {
            // 3h after first result
            scheduleNotification(.sampler_first_result, delay: 3 * 60 * 60)
        }
    }
    
    // MARK: - Schedule After Purchase
    func scheduleAfterPurchase(isCreatorMode: Bool = false) {
        if isCreatorMode {
            // Schedule Creator Mode reminders
            scheduleEveningNotification(.creator_day1, hour: 19, minute: 0)
            scheduleNotification(.creator_day5, delay: 5 * 24 * 60 * 60)
        } else {
            // Pack purchase
            scheduleNotification(.buyer_t24_purchase, delay: 24 * 60 * 60)
        }
    }
    
    // MARK: - Private: Schedule with Delay
    private func scheduleNotification(_ key: NotificationKey, delay: TimeInterval) {
        guard let copy = copyLibrary[key] else { return }
        
        // Check quiet hours
        let scheduledDate = Date().addingTimeInterval(delay)
        let hour = Calendar.current.component(.hour, from: scheduledDate)
        
        if hour >= quietHourStart || hour < quietHourEnd {
            // Reschedule for 9 AM next day
            let adjustedDelay = delay + Double((quietHourEnd - hour + 24) % 24) * 3600
            scheduleNotificationInternal(key, body: copy.randomBody, delay: adjustedDelay)
        } else {
            scheduleNotificationInternal(key, body: copy.randomBody, delay: delay)
        }
    }
    
    // MARK: - Private: Schedule at Specific Time
    private func scheduleEveningNotification(_ key: NotificationKey, hour: Int, minute: Int) {
        guard let copy = copyLibrary[key] else { return }
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let content = UNMutableNotificationContent()
        content.title = "Eclat"
        content.body = copy.randomBody
        content.sound = .default
        content.userInfo = ["deep_link": copy.deepLink, "notif_key": key.rawValue]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: key.rawValue, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule \(key.rawValue): \(error)")
            } else {
                print("✅ Scheduled \(key.rawValue) for \(hour):\(minute)")
            }
        }
    }
    
    private func scheduleNotificationInternal(_ key: NotificationKey, body: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Eclat"
        content.body = body
        content.sound = .default
        
        if let copy = copyLibrary[key] {
            content.userInfo = ["deep_link": copy.deepLink, "notif_key": key.rawValue]
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: key.rawValue, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule \(key.rawValue): \(error)")
            } else {
                print("✅ Scheduled \(key.rawValue) in \(Int(delay / 3600))h")
            }
        }
    }
    
    // MARK: - Handle Deep Link
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "eclat" else { return }
        
        let host = url.host ?? "home"
        
        Task { @MainActor in
            switch host {
            case "home":
                AppState().navigateTo(.home)
            case "history":
                AppState().showHistorySheet = true
            case "creator-mode", "packs":
                AppState().navigateTo(.creditsPaywall)
            default:
                AppState().navigateTo(.home)
            }
        }
    }
    
    // MARK: - Log Notification Opened (Analytics)
    func logNotificationOpened(notifKey: String) {
        print("📊 Notification opened: \(notifKey)")
        // TODO: Send to Supabase notification_log
    }
    
    // MARK: - Register Device Token
    func registerDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device token: \(tokenString)")
        
        // Save locally
        UserDefaults.standard.set(tokenString, forKey: "push_token")
        
        // TODO: Send to Supabase push_tokens table
    }
}

// MARK: - Pre-Permission Prompt View
import SwiftUI

struct PushPermissionPromptView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Text("Want a reminder for your next look?")
                    .font(.eclat.headlineMedium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("We'll only notify you when it's actually useful.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    NotificationManager.shared.requestPermission(afterWinMoment: true)
                    dismiss()
                } label: {
                    Text("Enable notifications")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white, in: Capsule())
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(hex: "0B0606"))
    }
}
