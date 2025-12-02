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
            print("📸 imagePickerController called with keys: \(info.keys.map { $0.rawValue })")
            
            // Try multiple sources for the picked image
            if let image = info[.originalImage] as? UIImage {
                print("✅ Got image from .originalImage (local file)")
                handlePicked(image: image)
                return
            }
            print("⚠️ .originalImage was nil")
            
            if let edited = info[.editedImage] as? UIImage {
                print("✅ Got image from .editedImage (user cropped)")
                handlePicked(image: edited)
                return
            }
            print("⚠️ .editedImage was nil")
            
            if let url = info[.imageURL] as? URL {
                print("📁 Found .imageURL: \(url.lastPathComponent)")
                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    print("✅ Got image from .imageURL (local file)")
                    handlePicked(image: img)
                    return
                }
                print("❌ Failed to load data from .imageURL")
            }
            print("⚠️ .imageURL was nil")
            
            if let asset = info[.phAsset] as? PHAsset {
                print("📷 Got PHAsset (possibly iCloud)")
                let opts = PHImageRequestOptions()
                opts.isNetworkAccessAllowed = true
                opts.deliveryMode = .highQualityFormat
                // Use async request; close picker in completion
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
                    if let data, let img = UIImage(data: data) {
                        print("✅ Got image from PHAsset")
                        self.handlePicked(image: img)
                    } else {
                        print("❌ Failed to load PHAsset (iCloud not available)")
                        self.parent.onError("Could not load selected image (iCloud asset not available). Please download the image locally and try again.")
                        self.parent.isPresented = false
                    }
                }
                return
            }
            print("⚠️ .phAsset was nil")
            
            // Handle legacy reference URL (for certain iCloud photos)
            if let referenceURL = info[.referenceURL] as? URL {
                print("📎 Found .referenceURL: \(referenceURL)")
                
                // Fetch the PHAsset from the reference URL
                // Note: Using deprecated APIs for legacy iCloud photo support (necessary for certain old iCloud photos)
                @available(iOS, deprecated: 11.0, message: "Necessary for legacy iCloud photo support")
                let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil)
                
                if let asset = fetchResult.firstObject {
                    print("📷 Got PHAsset from referenceURL")
                    parent.isPresented = false  // Dismiss picker immediately
                    
                    let opts = PHImageRequestOptions()
                    opts.isNetworkAccessAllowed = true
                    opts.deliveryMode = .highQualityFormat
                    opts.isSynchronous = false
                    
                    PHImageManager.default().requestImage(
                        for: asset,
                        targetSize: PHImageManagerMaximumSize,
                        contentMode: .aspectFit,
                        options: opts
                    ) { image, info in
                        DispatchQueue.main.async {
                            if let image = image {
                                print("✅ Got image from referenceURL PHAsset")
                                let validation = ArtworkValidator.validateImage(image)
                                if let error = validation.error {
                                    self.parent.onError(error)
                                    return
                                }
                                self.parent.onImageSelected(image)
                            } else {
                                print("❌ Failed to load image from referenceURL")
                                self.parent.onError("Could not load selected image. Please try a different photo.")
                            }
                        }
                    }
                    return
                } else {
                    print("❌ Could not fetch PHAsset from referenceURL")
                }
            }
            print("⚠️ .referenceURL was nil or could not be fetched")
            
            print("❌ All image sources failed. Available keys: \(info.keys.map { $0.rawValue }.joined(separator: ", "))")
            parent.onError("Could not load selected image")
            parent.isPresented = false
        }
        
        private func handlePicked(image: UIImage) {
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