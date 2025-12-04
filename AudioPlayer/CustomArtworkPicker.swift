//
//  CustomArtworkPicker.swift
//  FireVox
//
//  Created by Warp AI on 2025/10/27.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Photos
import PhotosUI

struct CustomArtworkPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageSelected: (UIImage) -> Void
    let onError: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: CustomArtworkPicker
        
        init(_ parent: CustomArtworkPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            defer {
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                    self.parent.dismiss()
                }
            }
            
            guard let result = results.first else {
                print("❌ No image selected")
                return
            }
            
            // PHPickerViewController handles all iCloud photo scenarios natively
            result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        print("✅ Got image from PHPickerViewController")
                        let validation = ArtworkValidator.validateImage(image)
                        if let validationError = validation.error {
                            self.parent.onError(validationError)
                            return
                        }
                        self.parent.onImageSelected(image)
                    } else {
                        print("❌ Failed to load image: \(error?.localizedDescription ?? "Unknown error")")
                        self.parent.onError("Could not load selected image. Please try again.")
                    }
                }
            }
        }
    }
}

struct ArtworkValidator {
    struct ValidationResult {
        let isValid: Bool
        let error: String?
    }
    
    static func validateImage(_ image: UIImage) -> ValidationResult {
        // Check aspect ratio (should be square)
        let aspectRatio = image.size.width / image.size.height
        let tolerance: CGFloat = 0.1 // Allow 10% tolerance
        
        if abs(aspectRatio - 1.0) > tolerance {
            return ValidationResult(
                isValid: false, 
                error: "Image must be square (current aspect ratio: \(String(format: "%.2f", aspectRatio)):1). Please select a square image."
            )
        }
        
        // Check file size (convert UIImage to data to estimate size)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return ValidationResult(isValid: false, error: "Could not process image data")
        }
        
        let maxSize = 1024 * 1024 // 1MB
        if imageData.count > maxSize {
            let sizeInMB = Double(imageData.count) / (1024 * 1024)
            return ValidationResult(
                isValid: false,
                error: "Image size is \(String(format: "%.2f", sizeInMB))MB. Maximum allowed size is 1MB. Please select a smaller image or compress the current one."
            )
        }
        
        // Check minimum dimensions to ensure quality
        let minDimension: CGFloat = 200
        if image.size.width < minDimension || image.size.height < minDimension {
            return ValidationResult(
                isValid: false,
                error: "Image is too small (\(Int(image.size.width))x\(Int(image.size.height))). Minimum size is \(Int(minDimension))x\(Int(minDimension)) pixels."
            )
        }
        
        return ValidationResult(isValid: true, error: nil)
    }
    
    static func processImageForArtwork(_ image: UIImage) -> Data? {
        // Ensure the image is square by cropping to the smaller dimension
        let size = min(image.size.width, image.size.height)
        let origin = CGPoint(
            x: (image.size.width - size) / 2,
            y: (image.size.height - size) / 2
        )
        
        let cropRect = CGRect(origin: origin, size: CGSize(width: size, height: size))
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return nil
        }
        
        let squareImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        // Convert to JPEG with good quality but reasonable file size
        return squareImage.jpegData(compressionQuality: 0.8)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = false
        @State private var selectedImage: UIImage?
        @State private var errorMessage = ""
        
        var body: some View {
            VStack {
                Button("Select Custom Artwork") {
                    isPresented = true
                }
                .sheet(isPresented: $isPresented) {
                    CustomArtworkPicker(
                        isPresented: $isPresented,
                        onImageSelected: { image in
                            selectedImage = image
                        },
                        onError: { error in
                            errorMessage = error
                        }
                    )
                }
                
                if !errorMessage.isEmpty {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
                
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                }
            }
        }
    }
    
    return PreviewWrapper()
}