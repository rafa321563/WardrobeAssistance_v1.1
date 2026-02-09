//
//  ItemEntity+Extensions.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
//import CoreData
import UIKit
import SwiftUI

extension ItemEntity {
    
    // MARK: - Enum Computed Properties
    
    /// Returns the category as a ClothingCategory enum, or nil if invalid
    var categoryEnum: ClothingCategory? {
        get {
            guard let category = category else { return nil }
                return ClothingCategory(rawValue: category)
        }
        set {
            category = newValue?.rawValue
        }
    }
    
    /// Returns the color as a ClothingColor enum, or nil if invalid
    var colorEnum: ClothingColor? {
        get {
            guard let colorString = color else { return nil }
            return ClothingColor(rawValue: colorString)
        }
        set {
            color = newValue?.rawValue
        }
    }
    
    /// Returns the season as a Season enum, or nil if invalid
    var seasonEnum: Season? {
        get {
            guard let seasonString = season else { return nil }
            return Season(rawValue: seasonString)
        }
        set {
            season = newValue?.rawValue
        }
    }
    
    /// Returns the style as a Style enum, or nil if invalid
    var styleEnum: Style? {
        get {
            guard let styleString = style else { return nil }
            return Style(rawValue: styleString)
        }
        set {
            style = newValue?.rawValue
        }
    }
    
    // MARK: - Tags Array Conversion
    
    /// Returns tags as an array of strings
    var tagsArray: [String] {
        get {
            guard let tagsString = tags, !tagsString.isEmpty else { return [] }
            return tagsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.isEmpty ? nil : newValue.joined(separator: ", ")
        }
    }
    
    // MARK: - Image Loading
    
    /// Asynchronously loads the image with RAM caching
    /// Checks ImageCache first, then loads from disk if needed
    /// - Returns: The UIImage if found, nil otherwise
    func loadImageAsync() async -> UIImage? {
        guard let filename = imageFileName, !filename.isEmpty else {
            return nil
        }
        
        // Check RAM cache first
        if let cachedImage = ImageCache.shared.image(for: filename) {
            return cachedImage
        }
        
        // Load from disk on background thread
        return await Task.detached(priority: .userInitiated) {
            guard let image = ImageFileManager.shared.loadImage(filename: filename) else {
                return nil
            }
            
            // Cache the loaded image
            ImageCache.shared.set(image, for: filename)
            
            return image
        }.value
    }
    
    /// Synchronously loads the image from disk (DEPRECATED - use loadImageAsync instead)
    /// ⚠️ WARNING: This performs disk I/O on the calling thread. Use loadImageAsync() for better performance.
    /// - Returns: The UIImage if found, nil otherwise
    @available(*, deprecated, message: "Use loadImageAsync() instead to avoid blocking the main thread")
    var uiImage: UIImage? {
        guard let filename = imageFileName else { return nil }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.image(for: filename) {
            return cachedImage
        }
        
        // Fallback to disk (synchronous - not recommended)
        guard let image = ImageFileManager.shared.loadImage(filename: filename) else {
            return nil
        }
        
        // Cache for future use
        ImageCache.shared.set(image, for: filename)
        
        return image
    }
    
    /// Returns a SwiftUI Image from the disk-stored image (DEPRECATED)
    /// ⚠️ WARNING: This performs synchronous disk I/O. Use CachedImageView instead.
    @available(*, deprecated, message: "Use CachedImageView instead for async loading")
    var swiftUIImage: Image? {
        guard let uiImage = uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
    
    // MARK: - Convenience Properties
    
    /// Safe name access with fallback
    var displayName: String {
        name ?? "Unnamed Item"
    }
    
    /// Safe category access with fallback
    var displayCategory: ClothingCategory {
        categoryEnum ?? .tops
    }
    
    /// Safe color access with fallback
    var displayColor: ClothingColor {
        colorEnum ?? .black
    }
    
    /// Safe season access with fallback
    var displaySeason: Season {
        seasonEnum ?? .allSeason
    }
    
    /// Safe style access with fallback
    var displayStyle: Style {
        styleEnum ?? .casual
    }

    /// Returns the size string if set
    var displaySize: String? { size }
    
    // MARK: - Wear Count Management
    
    /// Marks the item as worn (increments count and updates lastWorn date)
    func markAsWorn() {
        wearCount += 1
        lastWorn = Date()
    }
}

