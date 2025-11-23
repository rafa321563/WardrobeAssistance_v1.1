//
//  OutfitDataService.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import CoreData
import UIKit

/// Service layer for all Core Data write operations for OutfitEntity
/// All writes happen on background contexts to avoid blocking the UI
final class OutfitDataService {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create Outfit
    
    /// Creates a new outfit on a background context
    /// - Parameters:
    ///   - name: Outfit name
    ///   - items: Array of ItemEntity UUIDs
    ///   - occasion: Occasion
    ///   - season: Season
    ///   - notes: Optional notes
    ///   - image: Optional preview image (will be stored as Binary Data in Core Data)
    ///   - rating: Optional rating (1-5)
    /// - Returns: The created OutfitEntity's UUID
    func createOutfit(
        name: String,
        items: [UUID],
        occasion: Occasion,
        season: Season,
        notes: String? = nil,
        image: UIImage? = nil,
        rating: Int? = nil
    ) async throws -> UUID {
        return try await persistenceController.performBackgroundTask { context in
            let outfit = OutfitEntity(context: context)
            outfit.id = UUID()
            outfit.name = name
            outfit.itemsArray = items
            outfit.occasion = occasion.rawValue
            outfit.season = season.rawValue
            outfit.notes = notes
            outfit.dateCreated = Date()
            outfit.wearCount = 0
            outfit.isFavorite = false
            outfit.lastWorn = nil
            // Note: For optional scalar types in Core Data, we only set if we have a value
            if let ratingValue = rating {
                outfit.setPrimitiveValue(Int32(ratingValue), forKey: "rating")
            }
            // Note: If rating is nil, Core Data will use the default value (nil for optional types)
            
            // Store image as binary data
            if let image = image {
                outfit.imageData = image.jpegData(compressionQuality: 0.8)
            }
            
            guard let outfitId = outfit.id else {
                throw OutfitDataError.outfitNotFound
            }
            return outfitId
        }
    }
    
    // MARK: - Update Outfit
    
    /// Updates an existing outfit on a background context
    /// - Parameters:
    ///   - id: The UUID of the outfit to update
    ///   - name: Updated name (optional)
    ///   - items: Updated items array (optional)
    ///   - occasion: Updated occasion (optional)
    ///   - season: Updated season (optional)
    ///   - notes: Updated notes (optional)
    ///   - image: Updated image (optional)
    ///   - rating: Updated rating (optional)
    func updateOutfit(
        id: UUID,
        name: String? = nil,
        items: [UUID]? = nil,
        occasion: Occasion? = nil,
        season: Season? = nil,
        notes: String? = nil,
        image: UIImage? = nil,
        rating: Int? = nil
    ) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Fetch the outfit
            let request: NSFetchRequest<OutfitEntity> = OutfitEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let outfit = try context.fetch(request).first else {
                throw OutfitDataError.outfitNotFound
            }
            
            // Update properties
            if let name = name {
                outfit.name = name
            }
            if let items = items {
                outfit.itemsArray = items
            }
            if let occasion = occasion {
                outfit.occasion = occasion.rawValue
            }
            if let season = season {
                outfit.season = season.rawValue
            }
            if let notes = notes {
                outfit.notes = notes.isEmpty ? nil : notes
            }
            if let image = image {
                outfit.imageData = image.jpegData(compressionQuality: 0.8)
            }
            // Note: For optional scalar types in Core Data, we only set if we have a value
            if let ratingValue = rating {
                outfit.setPrimitiveValue(Int32(ratingValue), forKey: "rating")
            }
            // Note: In updateOutfit, we don't set nil if rating is not provided (to preserve existing value)
        }
    }
    
    // MARK: - Delete Outfit
    
    /// Deletes an outfit
    /// - Parameter id: The UUID of the outfit to delete
    func deleteOutfit(id: UUID) async throws {
        try await persistenceController.performBackgroundTask { context in
            // Fetch the outfit
            let request: NSFetchRequest<OutfitEntity> = OutfitEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let outfit = try context.fetch(request).first else {
                throw OutfitDataError.outfitNotFound
            }
            
            // Delete the entity
            context.delete(outfit)
        }
    }
    
    // MARK: - Toggle Favorite
    
    /// Toggles the favorite status of an outfit
    /// - Parameter id: The UUID of the outfit
    func toggleFavorite(id: UUID) async throws {
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<OutfitEntity> = OutfitEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let outfit = try context.fetch(request).first else {
                throw OutfitDataError.outfitNotFound
            }
            
            outfit.isFavorite.toggle()
        }
    }
    
    // MARK: - Mark as Worn
    
    /// Marks an outfit as worn (increments wear count and updates lastWorn date)
    /// - Parameter id: The UUID of the outfit
    func markAsWorn(id: UUID) async throws {
        try await persistenceController.performBackgroundTask { context in
            let request: NSFetchRequest<OutfitEntity> = OutfitEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            guard let outfit = try context.fetch(request).first else {
                throw OutfitDataError.outfitNotFound
            }
            
            outfit.wearCount += 1
            outfit.lastWorn = Date()
        }
    }
}

// MARK: - Errors

enum OutfitDataError: LocalizedError {
    case outfitNotFound
    
    var errorDescription: String? {
        switch self {
        case .outfitNotFound:
            return "Outfit not found in database"
        }
    }
}

