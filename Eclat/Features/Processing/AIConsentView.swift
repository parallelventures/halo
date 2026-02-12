//
//  AIConsentView.swift
//  Eclat
//
//  Required by App Store Guideline 5.1.1 & 5.1.2
//  Must clearly disclose: what data is sent, who it's sent to,
//  and obtain user permission before sharing with third-party AI.
//

import SwiftUI

struct AIConsentView: View {
    
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "0B0606")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    
                    // MARK: - Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.and.background.dotted")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .padding(.top, 40)
                        
                        Text("Before We Begin")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Eclat uses AI to generate your hairstyle preview. Here's how your data is handled:")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Data Disclosure Cards
                    VStack(spacing: 16) {
                        
                        // What data is sent
                        ConsentInfoCard(
                            icon: "photo.fill",
                            title: "What data is sent",
                            description: "Your selfie photo (face image) is sent to our secure server, which forwards it to an AI service for hairstyle generation."
                        )
                        
                        // Who receives it
                        ConsentInfoCard(
                            icon: "building.2.fill",
                            title: "Who receives your data",
                            description: "Your photo is processed by Google (Gemini AI). Google processes your image in real-time to generate the hairstyle preview."
                        )
                        
                        // How it's used
                        ConsentInfoCard(
                            icon: "sparkles",
                            title: "How it's used",
                            description: "Your photo is used solely to generate a hairstyle preview. It is not used for advertising, profiling, or any other purpose."
                        )
                        
                        // Retention
                        ConsentInfoCard(
                            icon: "clock.fill",
                            title: "Data retention",
                            description: "Google does not retain your photo after processing. Your original selfie is stored on our servers while your account is active. You can delete it at any time."
                        )
                        
                        // No sharing
                        ConsentInfoCard(
                            icon: "lock.shield.fill",
                            title: "No additional sharing",
                            description: "Your face data is not sold, shared with other third parties, or used for facial recognition or identification."
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Privacy Policy Link
                    Link(destination: URL(string: "https://parallelventures.eu/privacy-policy/")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                            Text("Read our full Privacy Policy")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // MARK: - Buttons
                    VStack(spacing: 12) {
                        Button {
                            onAccept()
                        } label: {
                            Text("I Agree — Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.white, in: Capsule())
                        }
                        
                        Button {
                            onDecline()
                        } label: {
                            Text("Decline")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Info Card Component
struct ConsentInfoCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    AIConsentView(onAccept: {}, onDecline: {})
}
