//
//  PushPermissionView.swift
//  Eclat
//
//  Top-tier notification permission pre-prompt
//  High CVR design with segment-based copy variants
//

import SwiftUI

// MARK: - Permission Copy Variant
enum PermissionCopyVariant {
    case usefulOnly       // Version A - Best all-around
    case premiumIdentity  // Version B - For explorers
    case protectDecision  // Version C - For buyers
    
    var title: String {
        switch self {
        case .usefulOnly:
            return "Want a reminder for your next look?"
        case .premiumIdentity:
            return "Stay in flow"
        case .protectDecision:
            return "Make the decision easier"
        }
    }
    
    var subtitle: String {
        switch self {
        case .usefulOnly:
            return "We'll only notify you when it's actually useful."
        case .premiumIdentity:
            return "Get a gentle nudge when it's time to explore again."
        case .protectDecision:
            return "We'll remind you to compare your looks before you commit."
        }
    }
    
    var bullets: [String] {
        switch self {
        case .usefulOnly:
            return [
                "New looks you haven't tried yet",
                "A few looks left (so you don't get interrupted)",
                "When your next look is ready"
            ]
        case .premiumIdentity:
            return [
                "Try the next style in seconds",
                "Keep exploring without interruptions",
                "New looks, curated for you"
            ]
        case .protectDecision:
            return [
                "Revisit your top looks",
                "Try one more version",
                "Keep your progress saved"
            ]
        }
    }
    
    var primaryCTA: String {
        switch self {
        case .usefulOnly, .protectDecision:
            return "Enable notifications"
        case .premiumIdentity:
            return "Turn on reminders"
        }
    }
    
    var footer: String {
        switch self {
        case .usefulOnly:
            return "No spam. No promos."
        case .premiumIdentity:
            return "Only when helpful."
        case .protectDecision:
            return "You can change this anytime."
        }
    }
    
    static func forSegment(_ segment: UserSegment) -> PermissionCopyVariant {
        switch segment {
        case .tourist, .sampler:
            return .usefulOnly
        case .explorer, .power:
            return .premiumIdentity
        case .buyer:
            return .protectDecision
        }
    }
}

// MARK: - Push Permission View
struct PushPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    let variant: PermissionCopyVariant
    let onAllow: () -> Void
    let onDismiss: () -> Void
    
    @State private var showIOSPrompt = false
    @State private var isAnimatingIn = false
    
    init(
        segment: UserSegment = .tourist,
        onAllow: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.variant = PermissionCopyVariant.forSegment(segment)
        self.onAllow = onAllow
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Icon
                Image(systemName: "bell")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 32)
                
                // Title
                Text(variant.title)
                    .font(.eclat.headlineMedium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Subtitle
                Text(variant.subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                
                // Bullets
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(variant.bullets, id: \.self) { bullet in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                            Text(bullet)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(.top, 32)
                .padding(.horizontal, 48)
                
                // Momentum footer
                Text("So you never lose momentum.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .italic()
                    .padding(.top, 24)
                
                Spacer()
                
                // CTAs
                VStack(spacing: 12) {
                    // Primary CTA
                    Button {
                        HapticManager.shared.buttonPress()
                        handleAllowTapped()
                    } label: {
                        Text(variant.primaryCTA)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white, in: Capsule())
                    }
                    
                    // Secondary CTA
                    Button {
                        handleNotNowTapped()
                    } label: {
                        Text("Not now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                
                // Footer
                Text(variant.footer)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.top, 16)
                
                // iOS prompt priming
                Text("Next you'll see iOS asking for permission.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
        }
        .scaleEffect(isAnimatingIn ? 1 : 0.95)
        .opacity(isAnimatingIn ? 1 : 0)
        .onAppear {
            withAnimation(.eclatPhysical) {
                isAnimatingIn = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleAllowTapped() {
        // Request actual iOS permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    // Show confirmation toast
                    showConfirmationToast()
                    
                    // Mark as asked in UserDefaults
                    NotificationPermissionManager.shared.markAsAsked(allowed: true)
                    
                    // Schedule first notification (6-24h based on segment)
                    NotificationManager.shared.scheduleSmartNotifications()
                    
                    onAllow()
                } else {
                    // User denied at system level
                    NotificationPermissionManager.shared.markAsAsked(allowed: false)
                    showSettingsOption()
                }
                dismiss()
            }
        }
    }
    
    private func handleNotNowTapped() {
        // Set cooldown
        NotificationPermissionManager.shared.markAsDeclined()
        onDismiss()
        dismiss()
    }
    
    private func showConfirmationToast() {
        // The toast is shown via a notification or overlay in the parent view
        NotificationCenter.default.post(name: .showToast, object: "Reminders enabled.")
    }
    
    private func showSettingsOption() {
        // Show settings deep link option
        NotificationCenter.default.post(name: .showSettingsPrompt, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showToast = Notification.Name("showToast")
    static let showSettingsPrompt = Notification.Name("showSettingsPrompt")
}

// MARK: - Permission Manager
class NotificationPermissionManager {
    static let shared = NotificationPermissionManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let promptCount = "push_permission_prompt_count"
        static let lastPromptDate = "push_permission_last_prompt"
        static let systemDenied = "push_permission_system_denied"
        static let enabled = "push_permission_enabled"
    }
    
    // MARK: - Eligibility Check
    
    /// Check if we can show the pre-permission prompt
    var canShowPrompt: Bool {
        // Never show again if system denied
        if defaults.bool(forKey: Keys.systemDenied) {
            return false
        }
        
        // Already enabled
        if defaults.bool(forKey: Keys.enabled) {
            return false
        }
        
        // Max 2 lifetime prompts
        if promptCount >= 2 {
            return false
        }
        
        // 7 day cooldown after "Not now"
        if let lastPrompt = defaults.object(forKey: Keys.lastPromptDate) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            if daysSinceLastPrompt < 7 {
                return false
            }
        }
        
        return true
    }
    
    var promptCount: Int {
        defaults.integer(forKey: Keys.promptCount)
    }
    
    // MARK: - Mark Actions
    
    func markAsAsked(allowed: Bool) {
        defaults.set(promptCount + 1, forKey: Keys.promptCount)
        defaults.set(Date(), forKey: Keys.lastPromptDate)
        
        if allowed {
            defaults.set(true, forKey: Keys.enabled)
        } else {
            defaults.set(true, forKey: Keys.systemDenied)
        }
    }
    
    func markAsDeclined() {
        defaults.set(promptCount + 1, forKey: Keys.promptCount)
        defaults.set(Date(), forKey: Keys.lastPromptDate)
    }
    
    // MARK: - Reset (for testing)
    
    func reset() {
        defaults.removeObject(forKey: Keys.promptCount)
        defaults.removeObject(forKey: Keys.lastPromptDate)
        defaults.removeObject(forKey: Keys.systemDenied)
        defaults.removeObject(forKey: Keys.enabled)
    }
}

// MARK: - Settings Prompt View
struct SettingsPromptView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Text("No problem")
                    .font(.eclat.headlineMedium)
                    .foregroundColor(.white)
                
                Text("You can turn reminders on anytime in Settings.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    openSettings()
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white, in: Capsule())
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(hex: "0B0606"))
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    PushPermissionView(segment: .tourist)
}
