//
//  HomeView.swift
//  Halo
//
//  Premium home screen - redesigned
//

import SwiftUI
import PhotosUI

struct HomeView: View {
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showAccountSheet = false
    
    var body: some View {
        ZStack {
            // Aurora background
            AnimatedDarkGradient()
            
            // Main content
            // Main content
            ZStack(alignment: .top) {
                // ScrollView (Behind header)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Spacer for header
                        Color.clear.frame(height: 80)
                    
                    // MARK: - Hero Card
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text("AI Hairstyle Try-On")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("See yourself with new looks instantly")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .glassCardStyle()
                    
                    // MARK: - Quick Actions
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("QUICK START")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1)
                        
                        HStack(spacing: Spacing.sm) {
                            // Take Selfie
                            Button {
                                HapticManager.shared.buttonPress()
                                appState.showCameraSheet = true
                            } label: {
                                ZStack(alignment: .bottom) {
                                    Image("Selfie")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1.0, contentMode: .fit)
                                        .clipped()
     
                                    Text("Take Selfie")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .glassBubbleStyle()
                                        .padding(.bottom, 12)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            // From Gallery
                            Button {
                                HapticManager.shared.buttonPress()
                                showingPhotoPicker = true
                            } label: {
                                ZStack(alignment: .bottom) {
                                    // Stack effect avec 3 images
                                    ZStack {
                                        // Image 1 (arrière)
                                        Image("Selfie1")
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 130, height: 165)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .offset(x: -8, y: -8)
                                            .rotationEffect(.degrees(-5))
                                            .opacity(0.6)
                                        
                                        // Image 2 (milieu)
                                        Image("Selfie2")
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 135, height: 170)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .offset(x: 4, y: -4)
                                            .rotationEffect(.degrees(0))
                                            .opacity(0.8)
                                        
                                        // Image 3 (devant)
                                        Image("Selfie3")
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 140, height: 175)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .rotationEffect(.degrees(5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                    
                                    // Label
                                    Text("From Gallery")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .glassBubbleStyle()
                                        .padding(.bottom, 12)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Recent (if available)
                    if let image = appState.generatedImage {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("RECENT")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(1)
                            
                            Button {
                                HapticManager.shared.buttonPress()
                                appState.navigateTo(.result)
                            } label: {
                                HStack(spacing: Spacing.md) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .blur(radius: subscriptionManager.isSubscribed ? 0 : 6)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(appState.selectedHairstyle?.name ?? "Your Look")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Text("Tap to view")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(Spacing.md)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 120)
            }
            
            // MARK: - Variable Blur Layer (under header)
            VStack {
                VariableBlurView(radius: 15, mask: .progressiveBlurMask)
                    .frame(height: 100)
                    .ignoresSafeArea(edges: .top)
                Spacer()
            }
            .allowsHitTesting(false)
            
            // MARK: - Sticky Header
            HStack {
                Text("Halo")
                    .font(.halo.displaySmall)
                    .foregroundColor(.white)
                    .fixedSize()
                    .padding(.vertical, 4)
                
                Spacer()
                
                // History
                Button {
                    HapticManager.shared.buttonPress()
                    appState.showHistorySheet = true
                } label: {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 48, height: 48)
                }
                .glassCircleStyle()
                
                // Account button
                Button {
                    HapticManager.shared.buttonPress()
                    showAccountSheet = true
                } label: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 48, height: 48)
                }
                .glassCircleStyle()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.md)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.5), location: 0),
                        .init(color: Color.black.opacity(0.3), location: 0.5),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )
            }
            
            // MARK: - Bottom CTA
            VStack {
                Spacer()
                
                Button {
                    HapticManager.shared.buttonPress()
                    appState.showCameraSheet = true
                } label: {
                    Text("Try New Look")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .glassCTAStyle()
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task { await loadPhoto(newValue) }
        }
    }
    
    // MARK: - Load Photo
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            appState.setCapturedImage(image)
        }
    }
}

// MARK: - Glass Style Extensions
extension View {
    @ViewBuilder
    func glassCTAStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    func glassCircleStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            self
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    func glassChipStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    func glassBubbleStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular, in: Capsule())
        } else {
            self
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
    
    @ViewBuilder
    func glassCardStyle(cornerRadius: CGFloat = 24) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(.clear)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(SubscriptionManager())
}

// MARK: - Account Sheet
struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showDeleteAlert = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if subscriptionManager.isSubscribed {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                Text("Pro Member")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text("Free Account")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 20)
                    
                    // Subscription Section
                    VStack(spacing: 0) {
                        if !subscriptionManager.isSubscribed {
                            AccountRow(
                                icon: "crown.fill",
                                iconColor: .yellow,
                                title: "Upgrade to Pro",
                                subtitle: "Unlock unlimited generations"
                            ) {
                                // Navigate to paywall
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    appState.navigateTo(.paywall)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                        }
                        
                        AccountRow(
                            icon: "creditcard",
                            iconColor: .blue,
                            title: "Manage Subscription",
                            subtitle: subscriptionManager.isSubscribed ? "View or cancel" : "Restore purchases"
                        ) {
                            if subscriptionManager.isSubscribed {
                                openSubscriptionSettings()
                            } else {
                                Task {
                                    try? await subscriptionManager.restorePurchases()
                                }
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    
                    // Feedback Section
                    VStack(spacing: 0) {
                        AccountRow(
                            icon: "star.fill",
                            iconColor: .orange,
                            title: "Rate Halo",
                            subtitle: "Love the app? Leave a review!"
                        ) {
                            requestReview()
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        AccountRow(
                            icon: "envelope.fill",
                            iconColor: .green,
                            title: "Send Feedback",
                            subtitle: "We'd love to hear from you"
                        ) {
                            sendFeedback()
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        AccountRow(
                            icon: "questionmark.circle.fill",
                            iconColor: .purple,
                            title: "Help & Support",
                            subtitle: "Get help with Halo"
                        ) {
                            openURL("https://parallelventures.eu/support/")
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        AccountRow(
                            icon: "doc.text.fill",
                            iconColor: .gray,
                            title: "Privacy Policy",
                            subtitle: nil
                        ) {
                            openURL("https://parallelventures.eu/privacy-policy/")
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        AccountRow(
                            icon: "doc.text.fill",
                            iconColor: .gray,
                            title: "Terms of Service",
                            subtitle: nil
                        ) {
                            openURL("https://parallelventures.eu/terms-of-use/")
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    
                    // Account Actions
                    VStack(spacing: 0) {
                        AccountRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            iconColor: .red,
                            title: "Log Out",
                            subtitle: nil
                        ) {
                            showLogoutAlert = true
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        AccountRow(
                            icon: "trash.fill",
                            iconColor: .red,
                            title: "Delete Account",
                            subtitle: "Permanently remove your data"
                        ) {
                            showDeleteAlert = true
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    
                    // App Version
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("Version \(version)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 10)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.black)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    AuthService.shared.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await AuthService.shared.deleteAccount()
                        dismiss()
                    }
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func openSubscriptionSettings() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func requestReview() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendFeedback() {
        if let url = URL(string: "https://parallelventures.eu/support/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSupport() {
        if let url = URL(string: "https://parallelventures.eu/support/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Account Row
struct AccountRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Notification for showing paywall
extension Notification.Name {
    static let showPaywall = Notification.Name("showPaywall")
}
