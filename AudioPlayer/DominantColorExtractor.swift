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
    
    func extractMostUsedColor(from imageURL: URL) async -> Color {
        // Check cache first
        if let cachedColor = colorCache[imageURL] {
            return cachedColor
        }
        
        guard let imageData = try? Data(contentsOf: imageURL),
              let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return Color.gray.opacity(0.2)
        }
        
        // Resize to smaller size for performance (e.g., 100x100)
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let resizedCGImage = resizedImage.cgImage else {
            UIGraphicsEndImageContext()
            return Color.gray.opacity(0.2)
        }
        UIGraphicsEndImageContext()
        
        // Get pixel data
        let width = resizedCGImage.width
        let height = resizedCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Color.gray.opacity(0.2)
        }
        
        context.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Count colors (bucket into ranges to reduce unique colors)
        var colorCounts: [String: Int] = [:]
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                
                // Bucket colors into ranges (reduce precision to group similar colors)
                let bucketSize = 32 // Adjust for more/less grouping
                let rBucket = UInt8((Int(r) / bucketSize) * bucketSize)
                let gBucket = UInt8((Int(g) / bucketSize) * bucketSize)
                let bBucket = UInt8((Int(b) / bucketSize) * bucketSize)
                
                let key = "\(rBucket)-\(gBucket)-\(bBucket)"
                colorCounts[key, default: 0] += 1
            }
        }
        
        // Find most common color
        guard let mostCommon = colorCounts.max(by: { $0.value < $1.value }),
              let components = mostCommon.key.split(separator: "-").compactMap({ UInt8($0) }) as [UInt8]?,
              components.count == 3 else {
            return Color.gray.opacity(0.2)
        }
        
        let color = Color(
            red: Double(components[0]) / 255.0,
            green: Double(components[1]) / 255.0,
            blue: Double(components[2]) / 255.0
        )
        
        // Cache the color
        colorCache[imageURL] = color
        
        print("Most used color: \(color)")
        return color
    }
}
