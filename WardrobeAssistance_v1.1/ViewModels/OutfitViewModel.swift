//
//  OutfitViewModel.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import UIKit

/// ViewModel for outfit management
/// Handles UI logic and delegates write operations to OutfitDataService
@MainActor
class OutfitViewModel: ObservableObject {
    private let dataService = OutfitDataService()
    private let wardrobeViewModel: WardrobeViewModel
    
    // Current outfit builder state
    @Published var currentOutfitItems: [UUID] = []
    
    init(wardrobeViewModel: WardrobeViewModel) {
        self.wardrobeViewModel = wardrobeViewModel
    }
    
    // MARK: - Write Operations
    
    /// Creates a new outfit
    func createOutfit(
        name: String,
        items: [UUID],
        occasion: Occasion,
        season: Season,
        notes: String? = nil,
        image: UIImage? = nil,
        rating: Int? = nil
    ) async {
        do {
            _ = try await dataService.createOutfit(
                name: name,
                items: items,
                occasion: occasion,
                season: season,
                notes: notes,
                image: image,
                rating: rating
            )
        } catch {
            print("Failed to create outfit: \(error.localizedDescription)")
        }
    }
    
    /// Updates an existing outfit
    func updateOutfit(
        id: UUID,
        name: String? = nil,
        items: [UUID]? = nil,
        occasion: Occasion? = nil,
        season: Season? = nil,
        notes: String? = nil,
        image: UIImage? = nil,
        rating: Int? = nil
    ) async {
        do {
            try await dataService.updateOutfit(
                id: id,
                name: name,
                items: items,
                occasion: occasion,
                season: season,
                notes: notes,
                image: image,
                rating: rating
            )
        } catch {
            print("Failed to update outfit: \(error.localizedDescription)")
        }
    }
    
    /// Deletes an outfit
    func deleteOutfit(id: UUID) async {
        do {
            try await dataService.deleteOutfit(id: id)
        } catch {
            print("Failed to delete outfit: \(error.localizedDescription)")
        }
    }
    
    /// Toggles favorite status
    func toggleFavorite(id: UUID) async {
        do {
            try await dataService.toggleFavorite(id: id)
        } catch {
            print("Failed to toggle favorite: \(error.localizedDescription)")
        }
    }
    
    /// Marks an outfit as worn
    func markAsWorn(id: UUID) async {
        do {
            try await dataService.markAsWorn(id: id)
            
            // Also mark individual items as worn
            let context = PersistenceController.shared.viewContext
            if let outfit = getOutfit(by: id, context: context) {
                for itemId in outfit.itemsArray {
                    await wardrobeViewModel.markAsWorn(id: itemId)
                }
            }
        } catch {
            print("Failed to mark outfit as worn: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Outfit Builder
    
    func addItemToCurrentOutfit(_ itemId: UUID) {
        if !currentOutfitItems.contains(itemId) {
            currentOutfitItems.append(itemId)
        }
    }
    
    func removeItemFromCurrentOutfit(_ itemId: UUID) {
        currentOutfitItems.removeAll { $0 == itemId }
    }
    
    func clearCurrentOutfit() {
        currentOutfitItems = []
    }
    
    func saveCurrentOutfit(
        name: String,
        occasion: Occasion,
        season: Season,
        notes: String? = nil
    ) async {
        await createOutfit(
            name: name.isEmpty ? "My Outfit" : name,
            items: currentOutfitItems,
            occasion: occasion,
            season: season,
            notes: notes
        )
        clearCurrentOutfit()
    }
    
    // MARK: - Read Operations
    
    /// Fetches a single outfit by ID from the view context
    func getOutfit(by id: UUID, context: NSManagedObjectContext) -> OutfitEntity? {
        let request: NSFetchRequest<OutfitEntity> = OutfitEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    /// Gets outfits for a specific occasion
    func getOutfitsForOccasion(_ occasion: Occasion, context: NSManagedObjectContext) -> [OutfitEntity] {
        let request: NSFetchRequest<OutfitEntity> = OutfitEntity.fetchRequest()
        request.predicate = NSPredicate(format: "occasion == %@", occasion.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \OutfitEntity.dateCreated, ascending: false)]
        
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - Outfit Recommendations
    
    /// Generates an outfit recommendation based on occasion, season, and weather
    func generateOutfitRecommendation(
        occasion: Occasion,
        season: Season,
        weather: WeatherData? = nil,
        context: NSManagedObjectContext
    ) -> [UUID]? {
        // Fetch all items
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        let allItems = (try? context.fetch(request)) ?? []
        
        // Filter by season
        let seasonItems = allItems.filter { item in
            item.seasonEnum == season || item.seasonEnum == .allSeason
        }
        
        // Filter by weather if available
        let weatherItems = weather != nil ? seasonItems.filter { item in
            if weather!.isCold && item.categoryEnum != .outerwear {
                return true // Allow non-outerwear, we'll add outerwear separately
            }
            return true
        } : seasonItems
        
        // Try to find matching items
        var recommendedItems: [UUID] = []
        
        // Find a top
        if let top = weatherItems.filter({ $0.categoryEnum == .tops }).randomElement(),
           let topId = top.id {
            recommendedItems.append(topId)
        }
        
        // Find bottoms or dress
        if let bottom = weatherItems.filter({ $0.categoryEnum == .bottoms || $0.categoryEnum == .dresses }).randomElement(),
           let bottomId = bottom.id {
            recommendedItems.append(bottomId)
        }
        
        // Find shoes
        if let shoes = weatherItems.filter({ $0.categoryEnum == .shoes }).randomElement(),
           let shoesId = shoes.id {
            recommendedItems.append(shoesId)
        }
        
        // Add outerwear if cold
        if let weather = weather, weather.isCold {
            if let outerwear = weatherItems.filter({ $0.categoryEnum == .outerwear }).randomElement(),
               let outerwearId = outerwear.id {
                recommendedItems.append(outerwearId)
            }
        }
        
        return recommendedItems.isEmpty ? nil : recommendedItems
    }
}

