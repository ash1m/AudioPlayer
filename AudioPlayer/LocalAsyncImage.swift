//
//  LocalAsyncImage.swift
//  FireVox
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
        .onChange(of: url) { oldValue, newValue in
            // Reload image whenever URL changes
            if oldValue?.path != newValue?.path {
                loadImage()
            }
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

// Image cache for LocalAsyncImageWithPhase to prevent repeated disk reads
fileprivate class ImageCache {
    static let shared = ImageCache()
    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.audioplayer.imagecache", attributes: .concurrent)
    
    func image(for url: URL) -> UIImage? {
        queue.sync {
            cache[url.absoluteString]
        }
    }
    
    func setImage(_ image: UIImage, for url: URL) {
        queue.async(flags: .barrier) {
            self.cache[url.absoluteString] = image
        }
    }
}

struct LocalAsyncImageWithPhase: View {
    let url: URL?
    let content: (LocalImagePhase) -> AnyView
    
    @State private var image: UIImage?
    @State private var isLoading: Bool = false
    @State private var error: Error?
    @State private var hasAttemptedLoad: Bool = false
    
    var body: some View {
        content(currentPhase)
            .onAppear {
                print("🎨 [LocalAsyncImageWithPhase] onAppear - URL: \(url?.lastPathComponent ?? "nil")")
                // Only load if we haven't already attempted for this URL
                if !hasAttemptedLoad {
                    hasAttemptedLoad = true
                    loadImage()
                } else if let cachedImage = url.flatMap({ ImageCache.shared.image(for: $0) }) {
                    // Use cached image if available
                    image = cachedImage
                }
            }
            .onChange(of: url) { oldValue, newValue in
                // Reload image whenever URL changes. Always reset state even if the path is the same,
                // because different files in a group may legitimately reuse the same artwork file.
                print("🎨 [LocalAsyncImageWithPhase] onChange triggered")
                print("   oldValue: \(oldValue?.lastPathComponent ?? "nil")")
                print("   newValue: \(newValue?.lastPathComponent ?? "nil")")
                hasAttemptedLoad = true
                resetState()
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
    
    private func resetState() {
        image = nil
        error = nil
        isLoading = false
    }
    
    private func loadImage() {
        guard let url = url else {
            print("🎨 [LocalAsyncImageWithPhase] loadImage: URL is nil")
            error = LocalImageError.invalidURL
            isLoading = false
            return
        }
        
        print("🎨 [LocalAsyncImageWithPhase] loadImage: Starting for \(url.lastPathComponent)")
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
                        // Cache the image for future use
                        ImageCache.shared.setImage(uiImage, for: url)
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
