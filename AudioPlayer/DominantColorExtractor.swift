//
//  DominantColorExtractor.swift
//  FireVox
//
//  Created by Assistant on 2025/11/11.
//

import SwiftUI
import CoreImage

actor DominantColorExtractor {
    static let shared = DominantColorExtractor()
    
    private var colorCache: [URL: Color] = [:]
    
    nonisolated private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    func extractDominantColor(from imageURL: URL) async -> Color {
        // Check cache first
        if let cachedColor = colorCache[imageURL] {
            return cachedColor
        }
        
        // Load and process image
        guard let imageData = try? Data(contentsOf: imageURL),
              let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return Color.gray.opacity(0.2) // Fallback color
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(ciImage.extent, forKey: kCIInputExtentKey)
        
        guard let outputImage = filter?.outputImage else {
            return Color.gray.opacity(0.2)
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        let red = Double(bitmap[0]) / 255.0
        let green = Double(bitmap[1]) / 255.0
        let blue = Double(bitmap[2]) / 255.0
        
        let color = Color(red: red, green: green, blue: blue)
        
        // Cache the color
        colorCache[imageURL] = color
        
        print(color)
        return color
        
    }
}
