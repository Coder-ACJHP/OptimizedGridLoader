//
//  ImageLoader.swift
//  CollectionViewOptimization
//
//  Created by Coder ACJHP on 11.03.2026.
//

import Foundation
import UIKit

enum ImageError: Error {
    case decodeFailed
}

extension ImageError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .decodeFailed:
            return "Failed to decode image"
        }
    }
}

protocol ImageLoaderProtocol {
    func loadImage(from url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage
}

/// Thread-safe image loader with in-memory caching, request deduplication,
/// and background downsampling to minimize memory footprint and network usage.
actor ImageLoader: ImageLoaderProtocol {
    
    private let cache = NSCache<NSURL, UIImage>()
    
    /// Custom session with higher connection limit (12 vs default 6) and disk caching
    /// to allow more concurrent downloads from the same host.
    private let session = URLSessionFactory.make()
    
    /// Tracks in-flight download tasks per URL to avoid duplicate network requests.
    /// When a second request arrives for an already in-flight URL, it awaits
    /// the existing task instead of starting a new download.
    private var inFlightRequests: [NSURL: Task<UIImage, Error>] = [:]
    
    /// Loads an image from the given URL, returning a cached version immediately if available.
    /// Otherwise downloads, downsamples to `targetSize`, caches the result, and returns it.
    /// Duplicate requests for the same URL share a single network call.
    func loadImage(from url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        let nsURL = url as NSURL
        
        if let cachedImage = cache.object(forKey: nsURL) {
            return cachedImage
        }
        
        if let existingTask = inFlightRequests[nsURL] {
            return try await existingTask.value
        }
        
        let task = Task<UIImage, Error> {
            let (data, _) = try await session.data(from: url)
            
            guard let image = downsample(data: data, targetSize: targetSize, scale: scale) else {
                throw ImageError.decodeFailed
            }
            
            cache.setObject(image, forKey: nsURL)
            return image
        }
        
        inFlightRequests[nsURL] = task
        defer { inFlightRequests.removeValue(forKey: nsURL) }
        
        return try await task.value
    }
    
    /// Creates a thumbnail-sized `UIImage` from raw data using `CGImageSource`,
    /// avoiding a full-resolution decode.
    private nonisolated func downsample(data: Data, targetSize: CGSize, scale: CGFloat) -> UIImage? {
        
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        
        let maxDimension = max(targetSize.width, targetSize.height) * scale
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, downsampleOptions as CFDictionary
        ) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
