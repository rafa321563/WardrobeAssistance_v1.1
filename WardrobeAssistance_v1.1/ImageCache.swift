//
//  ImageCache.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import UIKit
import CoreData

/// Thread-safe RAM cache for UIImage objects using NSCache
/// Automatically evicts images when memory pressure occurs
final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.name = "WardrobeImageCache"
        cache.countLimit = 100 // Store up to 100 images in RAM
        cache.totalCostLimit = 50 * 1024 * 1024 // Limit to ~50MB
    }
    
    /// Retrieves an image from the cache
    /// - Parameter key: The cache key (typically image filename)
    /// - Returns: The cached UIImage if found, nil otherwise
    func image(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    /// Stores an image in the cache
    /// - Parameters:
    ///   - image: The UIImage to cache
    ///   - key: The cache key (typically image filename)
    func set(_ image: UIImage, for key: String) {
        // Calculate approximate memory cost based on image data size
        let cost = image.jpegData(compressionQuality: 0.8)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    /// Removes an image from the cache
    /// - Parameter key: The cache key to remove
    func removeImage(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    /// Clears all cached images
    func removeAll() {
        cache.removeAllObjects()
    }
}

