//
//  AccountSheetOpal.swift
//  Eclat
//
//  "Your Studio"
//  Premium control room focusing on identity and value perception.
//

import SwiftUI
import StoreKit
import Intercom

struct AccountSheetOpal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var creditsService: CreditsService
    @ObservedObject private var generationService = GenerationService.shared
    
    // MARK: - Alert States
    @State private var showDeleteAlert = false
    @State private var showLogoutAlert = false
    
    // MARK: - Marquee State
    @State private var marqueeScrollIndex = 500
    private let marqueeTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            List {
                // 1. HERO - Introducing Looks / Upsell (Custom Section)
                Section {
                    heroSection
                        .listRowInsets(EdgeInsets()) // Remove default padding
                        .listRowBackground(Color.clear)
                }
                
                // 2. PURCHASES & ACCESS
                Section(header: Text("Purchases & Access")) {
                    Button {
                        Task { await subscriptionManager.restorePurchases() }
                    } label: {
                        HStack {
                            Label("Restore purchases", systemImage: "arrow.clockwise")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
                
                // 3. HELP & TRUST
                Section(header: Text("Help & Trust")) {
                    Button {
                        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                    } label: {
                        HStack {
                            Label("Rate Eclat", systemImage: "star.fill")
                                .symbolRenderingMode(.multicolor)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    
                    Button {
                        // Open Intercom messenger
                        Intercom.present()
                    } label: {
                        HStack {
                            Label("Send us a message", systemImage: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
                
                // 4. LEGAL (New Section for Clarity)
                Section(header: Text("Legal")) {
                    Link(destination: URL(string: "https://parallelventures.eu/privacy-policy/")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .foregroundColor(.white)
                    }
                    
                    Link(destination: URL(string: "https://parallelventures.eu/terms-of-use/")!) {
                        Label("Terms of Use", systemImage: "doc.text.fill")
                            .foregroundColor(.white)
                    }
                }

                // 5. ACCOUNT ACTIONS
                Section {
                    if AuthService.shared.isAuthenticated {
                        // Authenticated - show logout/delete options
                        Button {
                            showLogoutAlert = true
                        } label: {
                            Text("Log Out")
                                .foregroundColor(.red)
                        }
                        
                        Button {
                            showDeleteAlert = true
                        } label: {
                            Text("Delete Account")
                                .foregroundColor(.red)
                        }
                    } else {
                        // Not authenticated - show sign in options
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                appState.showAuthSheet = true
                            }
                        } label: {
                            HStack {
                                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Required to generate")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                } footer: {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("v\(version)")
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your Studio")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
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
                Text("This action cannot be undone. All your data and remaining looks will be lost.")
            }
        }
        .preferredColorScheme(.dark) // Force dark mode for premium feel
        .task {
            // Ensure stats are up to date
             await generationService.fetchGenerations()
        }
    }
    
    // MARK: - 1. Hero Section (Marquee Style)
    private var heroSection: some View {
        VStack(spacing: 24) {
            
            // Marquee Visual
            styleStackVisual
                .frame(height: 220) // Adjusted height for settings context
                .padding(.top, 16)
            
            // Title & Description
            VStack(spacing: 10) {
                Text("Introducing Looks ✨")
                    .font(.eclat.displayMedium)
                    .foregroundColor(.white)
                
                Text("Looks are credits you use to try new hairstyles.\nEach transformation costs one look.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // CTA Button (Capsule, no arrow)
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.navigateTo(.creditsPaywall)
                }
            } label: {
                Text(creditsService.balance > 0 ? "Explore more looks" : "Get your first looks")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain) // Important within List
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "080606")) // Plain dark background, no Aurora
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Marquee Content
    private var styleStackVisual: some View {
        // Combine Styles and Colors for the marquee
        let styleImages = HairstyleData.women.compactMap { $0.imageName }
        let colorImages = HairColorData.allColors.map { $0.imageName }
        let allImages = styleImages + colorImages
        
        let cardWidth: CGFloat = 140 // Smaller than paywall
        let cardHeight: CGFloat = 200
        
        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        // Create a virtual infinite list
                        ForEach(0..<1000) { index in
                            let imageName = allImages[index % allImages.count]
                            let isActive = index == marqueeScrollIndex
                            
                            VStack(spacing: 0) {
                                Image(imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: cardWidth, height: cardHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(isActive ? 0.5 : 0.2), radius: isActive ? 8 : 4)
                            }
                            .id(index)
                            .scaleEffect(isActive ? 1.05 : 0.95)
                            .opacity(isActive ? 1.0 : 0.7)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: marqueeScrollIndex)
                        }
                    }
                    .padding(.horizontal, (geo.size.width - cardWidth) / 2) // Center active item
                }
                .scrollDisabled(true) // Disable manual scroll for pure marquee
                .onReceive(marqueeTimer) { _ in
                    let nextIndex = marqueeScrollIndex + 1
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                        marqueeScrollIndex = nextIndex
                        proxy.scrollTo(nextIndex, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(marqueeScrollIndex, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Components
    
    struct StatCard: View {
        let value: String
        let label: String
        let icon: String
        
        var body: some View {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
