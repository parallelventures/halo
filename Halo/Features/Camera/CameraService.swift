//
//  CameraService.swift
//  Halo
//
//  Camera capture service using AVFoundation
//

import AVFoundation
import UIKit
import SwiftUI

// MARK: - Camera Error
enum CameraError: LocalizedError {
    case accessDenied
    case accessRestricted
    case cameraUnavailable
    case captureError(Error)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Camera access was denied. Please enable it in Settings."
        case .accessRestricted:
            return "Camera access is restricted on this device."
        case .cameraUnavailable:
            return "Camera is not available."
        case .captureError(let error):
            return "Failed to capture photo: \(error.localizedDescription)"
        }
    }
}

// MARK: - Camera Service
@MainActor
final class CameraService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAuthorized = false
    @Published var isCameraReady = false
    @Published var capturedImage: UIImage?
    @Published var error: CameraError?
    @Published var isCapturing = false
    
    // MARK: - AVFoundation Properties
    let session = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?
    private var currentDevice: AVCaptureDevice?
    private var isUsingFrontCamera = true
    
    // MARK: - Continuation for async capture
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    
    // MARK: - Init
    override init() {
        super.init()
    }
    
    // MARK: - Check Authorization
    func checkAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            isAuthorized = true
            await setupCamera()
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isAuthorized = granted
            if granted {
                await setupCamera()
            } else {
                error = .accessDenied
            }
            
        case .denied:
            isAuthorized = false
            error = .accessDenied
            
        case .restricted:
            isAuthorized = false
            error = .accessRestricted
            
        @unknown default:
            isAuthorized = false
        }
    }
    
    // MARK: - Setup Camera
    private func setupCamera() async {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Get front camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            error = .cameraUnavailable
            session.commitConfiguration()
            return
        }
        
        currentDevice = device
        
        // Add input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            self.error = .captureError(error)
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        }
        
        session.commitConfiguration()
        isCameraReady = true
    }
    
    // MARK: - Start Session
    func startSession() {
        guard !session.isRunning else { return }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.startRunning()
        }
    }
    
    // MARK: - Stop Session
    func stopSession() {
        guard session.isRunning else { return }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    // MARK: - Capture Photo
    func capturePhoto() async throws -> UIImage {
        guard let photoOutput = photoOutput else {
            throw CameraError.cameraUnavailable
        }
        
        isCapturing = true
        defer { isCapturing = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - Switch Camera
    func switchCamera() {
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .back : .front
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            // Revert to previous input
            if session.canAddInput(currentInput) {
                session.addInput(currentInput)
            }
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentDevice = newDevice
            isUsingFrontCamera = !isUsingFrontCamera
        }
        
        session.commitConfiguration()
        HapticManager.light()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            if let error = error {
                photoContinuation?.resume(throwing: CameraError.captureError(error))
                photoContinuation = nil
                return
            }
            
            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                photoContinuation?.resume(throwing: CameraError.captureError(NSError(domain: "CameraService", code: -1)))
                photoContinuation = nil
                return
            }
            
            // Mirror the image if using front camera
            let finalImage: UIImage
            if isUsingFrontCamera, let cgImage = image.cgImage {
                finalImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
            } else {
                finalImage = image
            }
            
            capturedImage = finalImage
            photoContinuation?.resume(returning: finalImage)
            photoContinuation = nil
            
            HapticManager.success()
        }
    }
}

// MARK: - Camera Preview View (UIViewRepresentable)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
    }
}

class CameraPreviewUIView: UIView {
    
    var session: AVCaptureSession? {
        didSet {
            // Prevent re-assigning the same session which causes black flicker
            guard session !== oldValue else { return }
            guard let session = session else { return }
            previewLayer.session = session
        }
    }
    
    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
