//
//  CustomArtworkPicker.swift
//  AudioPlayer
//
//  Created by Warp AI on 2025/10/27.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CustomArtworkPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageSelected: (UIImage) -> Void
    let onError: (String) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.mediaTypes = [UTType.image.identifier]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CustomArtworkPicker
        
        init(_ parent: CustomArtworkPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onError("Could not load selected image")
                parent.isPresented = false
                return
            }
            
            // Validate image
            let validation = ArtworkValidator.validateImage(image)
            if let error = validation.error {
                parent.onError(error)
                parent.isPresented = false
                return
            }
            
            parent.onImageSelected(image)
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
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