//
//  LocalAsyncImage.swift
//  AudioPlayer
//
//  Created by Ashim S on 2025/01/28.
//

import SwiftUI
import UIKit

/// A custom image view that reliably loads local images with fallback handling
struct LocalAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading: Bool = false
    @State private var hasError: Bool = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if hasError || url == nil {
                placeholder()
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            hasError = true
            isLoading = false
            return
        }
        
        // Reset state
        image = nil
        hasError = false
        isLoading = true
        
        Task {
            do {
                let imageData = try Data(contentsOf: url)
                let uiImage = UIImage(data: imageData)
                
                await MainActor.run {
                    if let uiImage = uiImage {
                        self.image = uiImage
                        print("🎨 Successfully loaded local image: \(url.lastPathComponent)")
                    } else {
                        self.hasError = true
                        print("🎨 Failed to create UIImage from data for: \(url.path)")
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.hasError = true
                    self.isLoading = false
                    print("🎨 Error loading local image \(url.path): \(error)")
                }
            }
        }
    }
}

// Convenience initializers to match AsyncImage API
extension LocalAsyncImage where Content == Image, Placeholder == EmptyView {
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { EmptyView() }
        )
    }
}

extension LocalAsyncImage where Placeholder == EmptyView {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(
            url: url,
            content: content,
            placeholder: { EmptyView() }
        )
    }
}

// Phase-based API similar to AsyncImage
enum LocalImagePhase {
    case empty
    case success(Image)
    case failure(Error)
}

struct LocalAsyncImageWithPhase: View {
    let url: URL?
    let content: (LocalImagePhase) -> AnyView
    
    @State private var image: UIImage?
    @State private var isLoading: Bool = false
    @State private var error: Error?
    
    var body: some View {
        content(currentPhase)
            .onAppear {
                loadImage()
            }
            .onChange(of: url) { 
                loadImage()
            }
    }
    
    private var currentPhase: LocalImagePhase {
        if let image = image {
            return .success(Image(uiImage: image))
        } else if let error = error {
            return .failure(error)
        } else {
            return .empty
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            error = LocalImageError.invalidURL
            isLoading = false
            return
        }
        
        // Reset state
        image = nil
        error = nil
        isLoading = true
        
        Task {
            do {
                let imageData = try Data(contentsOf: url)
                let uiImage = UIImage(data: imageData)
                
                await MainActor.run {
                    if let uiImage = uiImage {
                        self.image = uiImage
                        print("🎨 Successfully loaded local image: \(url.lastPathComponent)")
                    } else {
                        self.error = LocalImageError.invalidImageData
                        print("🎨 Failed to create UIImage from data for: \(url.path)")
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    print("🎨 Error loading local image \(url.path): \(error)")
                }
            }
        }
    }
}

enum LocalImageError: Error, LocalizedError {
    case invalidURL
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .invalidImageData:
            return "Unable to create image from data"
        }
    }
}
