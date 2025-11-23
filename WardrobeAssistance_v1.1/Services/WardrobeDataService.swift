//
//  WardrobeDataService.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import CoreData
import UIKit

/// Service layer for all Core Data write operations
/// All writes happen on background contexts to avoid blocking the UI
final class WardrobeDataService {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create Item
    
    /// Creates a new wardrobe item on a background context
    /// - Parameters:
    ///   - name: Item name
    ///   - category: Clothing category
    ///   - color: Clothing color
    ///   - season: Season
    ///   - style: Style
    ///   - image: Optional UIImage (will be saved to disk)
    ///   - material: Optional material string
    ///   - brand: Optional brand string
    ///   - tags: Optional array of tags
    /// - Returns: The created ItemEntity's UUID
    func createItem(
        name: String,
        category: ClothingCategory,
        color: ClothingColor,
        season: Season,
        style: Style,
        image: UIImage? = nil,
        material: String? = nil,
        brand: String? = nil,
        tags: [String] = []
    ) async throws -> UUID {
        // Save image to disk first (on current thread - file I/O is fast)
        let imageFileName = image.flatMap { ImageFileManager.shared.saveImage($0) }
        
        // Create entity on background context
        return try await persistenceController.performBackgroundTask { context in
            let item = ItemEntity(context: context)
            item.id = UUID()
            item.name = name
            item.category = category.rawValue
            item.color = color.rawValue
            item.season = season.rawValue
            item.style = style.rawValue
            item.imageFileName = imageFileName
            item.material = material
            item.brand = brand
            item.tags = tags.isEmpty ? nil : tags.joined(separator: ", ")
            item.dateAdded = Date()
            item.wearCount = 0
            item.isFavorite = false
            item.lastWorn = nil
            
            guard let itemId = item.id else {
                throw WardrobeDataError.itemNotFound
            }
            return itemId
        }
    }
    
    // MARK: - Update Item
    
    /// Updates an existing wardrobe item on a background context
    /// - Parameters:
    ///   - id: The UUID of the item to update
    ///   - name: Updated name (optional)
    ///   - category: Updated category (optional)
    ///   - color: Updated color (optional)
    ///   - season: Updated season (optional)
    ///   - style: Updated style (optional)
    ///   - image: Updated image (optional, will replace existing)
    ///   - material: Updated material (optional)
    ///   - brand: Updated brand (optional)
    ///   - tags: Updated tags (optional)
    func updateItem(
        id: UUID,
        name: String? = nil,
        category: ClothingCategory? = nil,
        color: ClothingColor? = nil,
        season: Season? = nil,
        style: Style? = nil,
        image: UIImage? = nil,
        material: String? = nil,
        brand: String? = nil,
        tags: [String]? = nil
    ) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Fetch the item
            let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let item = try context.fetch(request).first else {
                throw WardrobeDataError.itemNotFound
            }
            
            // Delete old image if new one is provided
            if image != nil, let oldFileName = item.imageFileName {
                ImageFileManager.shared.deleteImage(filename: oldFileName)
            }
            
            // Save new image if provided
            if let newImage = image {
                item.imageFileName = ImageFileManager.shared.saveImage(newImage)
            }
            
            // Update properties
            if let name = name {
                item.name = name
            }
            if let category = category {
                item.category = category.rawValue
            }
            if let color = color {
                item.color = color.rawValue
            }
            if let season = season {
                item.season = season.rawValue
            }
            if let style = style {
                item.style = style.rawValue
            }
            if let material = material {
                item.material = material.isEmpty ? nil : material
            }
            if let brand = brand {
                item.brand = brand.isEmpty ? nil : brand
            }
            if let tags = tags {
                item.tags = tags.isEmpty ? nil : tags.joined(separator: ", ")
            }
        }
    }
    
    // MARK: - Delete Item
    
    /// Deletes a wardrobe item and its associated image file
    /// - Parameter id: The UUID of the item to delete
    func deleteItem(id: UUID) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Fetch the item
            let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let item = try context.fetch(request).first else {
                throw WardrobeDataError.itemNotFound
            }
            
            // Delete associated image file
            if let imageFileName = item.imageFileName {
                ImageFileManager.shared.deleteImage(filename: imageFileName)
            }
            
            // Delete the entity
            context.delete(item)
        }
    }
    
    // MARK: - Toggle Favorite
    
    /// Toggles the favorite status of an item
    /// - Parameter id: The UUID of the item
    func toggleFavorite(id: UUID) async throws {
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let item = try context.fetch(request).first else {
                throw WardrobeDataError.itemNotFound
            }
            
            item.isFavorite.toggle()
        }
    }
    
    // MARK: - Mark as Worn
    
    /// Marks an item as worn (increments wear count and updates lastWorn date)
    /// - Parameter id: The UUID of the item
    func markAsWorn(id: UUID) async throws {
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let item = try context.fetch(request).first else {
                throw WardrobeDataError.itemNotFound
            }
            
            item.wearCount += 1
            item.lastWorn = Date()
        }
    }
}

// MARK: - Errors

enum WardrobeDataError: LocalizedError {
    case itemNotFound
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in database"
        }
    }
}

