//
//  CameraView.swift
//  Halo
//
//  Minimal camera screen
//

import SwiftUI
import PhotosUI

// MARK: - Glass Circle Modifier
extension View {
    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .clipShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }
    
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self
                .clipShape(Capsule())
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct CameraView: View {
    
    @EnvironmentObject private var appState: AppState
    
    @StateObject private var cameraService = CameraService()
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showStyleSheet = false
    
    var body: some View {
        ZStack {
            // Camera
            Group {
                if cameraService.isCameraReady {
                    CameraPreviewView(session: cameraService.session)
                } else {
                    Color.black
                        .overlay(ProgressView().tint(.white))
                }
            }
            .ignoresSafeArea()
            
            // Simple oval guide
            ovalGuide
            
            // Controls
            VStack {
                // Top bar
                HStack {
                    Button {
                        HapticManager.shared.buttonPress()
                        appState.navigateTo(.home)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .glassCircle()
                    }
                    
                    Spacer()
                    
                    Button {
                        HapticManager.shared.buttonPress()
                        cameraService.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .glassCircle()
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                
                Spacer()
                
                // Bottom section
                VStack(spacing: Spacing.lg) {
                    // Selected style indicator
                    if let style = appState.selectedHairstyle {
                        Text(style.name)
                            .font(.halo.labelMedium)
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .glassCapsule()
                    } else {
                        Button {
                            HapticManager.shared.buttonPress()
                            showStyleSheet = true
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "sparkles")
                                Text("Choose a style")
                            }
                            .font(.halo.labelMedium)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .glassCapsule()
                        }
                    }
                    
                    // Capture row
                    HStack(spacing: 50) {
                        // Gallery
                        Button {
                            HapticManager.shared.buttonPress()
                            showingPhotoPicker = true
                        } label: {
                            Image(systemName: "photo")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .glassCircle()
                        }
                        
                        // Capture button
                        Button {
                            HapticManager.shared.buttonPress()
                            Task { await capturePhoto() }
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 3)
                                    .frame(width: 72, height: 72)
                                
                                Circle()
                                    .fill(.white)
                                    .frame(width: 58, height: 58)
                                    .scaleEffect(cameraService.isCapturing ? 0.9 : 1)
                                    .animation(.easeOut(duration: 0.1), value: cameraService.isCapturing)
                            }
                        }
                        .disabled(cameraService.isCapturing || appState.selectedHairstyle == nil)
                        .opacity(appState.selectedHairstyle == nil ? 0.4 : 1)
                        
                        // Styles
                        Button {
                            HapticManager.shared.buttonPress()
                            showStyleSheet = true
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .glassCircle()
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showStyleSheet) {
            StylePickerSheet(selectedStyle: $appState.selectedHairstyle)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task { await loadPhoto(newValue) }
        }
        .onAppear {
            Task {
                await cameraService.checkAuthorization()
                cameraService.startSession()
            }
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }
    
    private var ovalGuide: some View {
        GeometryReader { geo in
            let width = geo.size.width * 0.65
            let height = width * 1.35
            
            Ellipse()
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                .frame(width: width, height: height)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.4)
        }
        .allowsHitTesting(false)
    }
    
    private func capturePhoto() async {
        guard appState.selectedHairstyle != nil else {
            showStyleSheet = true
            return
        }
        
        do {
            let image = try await cameraService.capturePhoto()
            appState.setCapturedImage(image)
        } catch {
            appState.errorMessage = error.localizedDescription
            HapticManager.error()
        }
    }
    
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            appState.setCapturedImage(image)
        }
    }
}

// MARK: - Style Picker Sheet
struct StylePickerSheet: View {
    @Binding var selectedStyle: HairstyleOption?
    @State private var selectedCategory: HairstyleOption.HairstyleCategory = .trendy
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(HairstyleOption.HairstyleCategory.allCases, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Text(category.rawValue)
                                        .font(.halo.labelMedium)
                                        .foregroundColor(selectedCategory == category ? .primary : .secondary)
                                        .padding(.horizontal, Spacing.md)
                                        .padding(.vertical, Spacing.sm)
                                        .background(
                                            selectedCategory == category ? Color.primary.opacity(0.1) : Color.clear,
                                            in: Capsule()
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                    
                    // Styles grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                        ForEach(HairstyleOption.samples.filter { $0.category == selectedCategory }) { style in
                            Button {
                                selectedStyle = style
                                dismiss()
                            } label: {
                                VStack(spacing: Spacing.sm) {
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .fill(Color.secondary.opacity(0.1))
                                        .aspectRatio(3/4, contentMode: .fit)
                                        .overlay(
                                            Image(systemName: "scissors")
                                                .font(.title)
                                                .foregroundColor(.secondary)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                                .strokeBorder(
                                                    selectedStyle?.id == style.id ? Color.primary : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    
                                    Text(style.name)
                                        .font(.halo.labelSmall)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .padding(.vertical, Spacing.md)
            }
            .navigationTitle("Choose Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CameraView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
