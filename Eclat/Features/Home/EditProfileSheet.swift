//
//  EditProfileSheet.swift
//  Eclat
//
//  Profile editing sheet
//

import SwiftUI

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0B0606").ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // Profile Picture Section
                        VStack(spacing: 16) {
                            Text("Profile Picture")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button {
                                showImagePicker = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white.opacity(0.6))
                                        
                                        Text("Change")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 20)
                        
                        // Name Field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Name")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            TextField("Enter your name", text: $name)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        
                        // Username Field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Username")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            TextField("@username", text: $username)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .padding(16)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        
                        // Save Button
                        Button {
                            // Save logic here
                            HapticManager.shared.buttonPress()
                            dismiss()
                        } label: {
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
