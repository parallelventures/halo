//
//  AppDelegate.swift
//  Eclat
//
//  Handles push notifications and deep links
//

import UIKit
import UserNotifications
import Intercom

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - Application Lifecycle
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Initialize Intercom for customer support (launcher is shown only in-app, not during onboarding)
        Intercom.setApiKey("ios_sdk-964d50157d251626bd68d78d67f2828610cd71ef", forAppId: "b6sz5tiz")
        Intercom.setLauncherVisible(false) // Hidden by default, enabled in HomeView
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Check if launched from notification
        if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
            handleNotificationPayload(notification)
        }
        
        return true
    }
    
    // MARK: - Push Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationManager.shared.registerDeviceToken(deviceToken)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Handle Notification When App is Foreground
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground (optional)
        // For premium feel, you might want to NOT show banner when in-app
        let userInfo = notification.request.content.userInfo
        
        // Log the notification
        if let notifKey = userInfo["notif_key"] as? String {
            print("📬 Notification received in foreground: \(notifKey)")
        }
        
        // Don't show banner/sound when in foreground (premium approach)
        completionHandler([])
    }
    
    // MARK: - Handle Notification Tap
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        completionHandler()
    }
    
    // MARK: - Handle Notification Payload
    
    private func handleNotificationPayload(_ payload: [AnyHashable: Any]) {
        // Extract deep link
        if let deepLinkString = payload["deep_link"] as? String,
           let deepLinkURL = URL(string: deepLinkString) {
            Task { @MainActor in
                NotificationManager.shared.handleDeepLink(deepLinkURL)
            }
        }
        
        // Log notification opened
        if let notifKey = payload["notif_key"] as? String {
            Task { @MainActor in
                NotificationManager.shared.logNotificationOpened(notifKey: notifKey)
            }
        }
    }
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let handleDeepLink = Notification.Name("handleDeepLink")
}

