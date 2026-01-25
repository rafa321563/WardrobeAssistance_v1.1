//
//  WardrobeViewModel.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import UIKit

/// ViewModel for wardrobe management
/// Handles UI logic and delegates write operations to WardrobeDataService
/// Views should use @FetchRequest directly for reading data
@MainActor
class WardrobeViewModel: ObservableObject {
    private let dataService = WardrobeDataService()
    private let persistenceController = PersistenceController.shared
    
    init() {
        // Initialize with default values
    }
    
    // Filter state (Views can observe these)
    @Published var searchText: String = ""
    @Published var selectedCategory: ClothingCategory?
    @Published var selectedColor: ClothingColor?
    @Published var selectedSeason: Season?
    @Published var selectedStyle: Style?
    @Published var showFavoritesOnly: Bool = false
    
    // Error state
    @Published var error: Error?
    
    // MARK: - Write Operations
    
    /// Adds a new item to the wardrobe
    func addItem(
        name: String,
        category: ClothingCategory,
        color: ClothingColor,
        season: Season,
        style: Style,
        image: UIImage? = nil,
        material: String? = nil,
        brand: String? = nil,
        tags: [String] = []
    ) async {
        do {
            _ = try await dataService.createItem(
                name: name,
                category: category,
                color: color,
                season: season,
                style: style,
                image: image,
                material: material,
                brand: brand,
                tags: tags
            )
        } catch {
            self.error = error
            print("Failed to add item: \(error.localizedDescription)")
        }
    }
    
    /// Updates an existing item
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
    ) async {
        do {
            try await dataService.updateItem(
                id: id,
                name: name,
                category: category,
                color: color,
                season: season,
                style: style,
                image: image,
                material: material,
                brand: brand,
                tags: tags
            )
        } catch {
            self.error = error
            print("Failed to update item: \(error.localizedDescription)")
        }
    }
    
    /// Deletes an item
    func deleteItem(id: UUID) async {
        do {
            try await dataService.deleteItem(id: id)
        } catch {
            self.error = error
            print("Failed to delete item: \(error.localizedDescription)")
        }
    }
    
    /// Toggles favorite status
    func toggleFavorite(id: UUID) async {
        do {
            try await dataService.toggleFavorite(id: id)
        } catch {
            self.error = error
            print("Failed to toggle favorite: \(error.localizedDescription)")
        }
    }
    
    /// Marks an item as worn
    func markAsWorn(id: UUID) async {
        do {
            try await dataService.markAsWorn(id: id)
        } catch {
            self.error = error
            print("Failed to mark as worn: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Read Operations (Helper Methods)
    
    /// Fetches a single item by ID from the view context
    func getItem(by id: UUID, context: NSManagedObjectContext) -> ItemEntity? {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    // MARK: - Filtering (Builds NSPredicate for @FetchRequest)
    
    /// Builds a compound predicate for filtering items
    func buildFilterPredicate() -> NSPredicate? {
        var predicates: [NSPredicate] = []
        
        // Search text filter
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(
                format: "name CONTAINS[cd] %@ OR brand CONTAINS[cd] %@ OR tags CONTAINS[cd] %@",
                searchText, searchText, searchText
            )
            predicates.append(searchPredicate)
        }
        
        // Category filter
        if let category = selectedCategory {
            predicates.append(NSPredicate(format: "category == %@", category.rawValue))
        }
        
        // Color filter
        if let color = selectedColor {
            predicates.append(NSPredicate(format: "color == %@", color.rawValue))
        }
        
        // Season filter
        if let season = selectedSeason {
            predicates.append(NSPredicate(format: "season == %@ OR season == %@", season.rawValue, Season.allSeason.rawValue))
        }
        
        // Style filter
        if let style = selectedStyle {
            predicates.append(NSPredicate(format: "style == %@", style.rawValue))
        }
        
        // Favorites filter
        if showFavoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }
        
        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    /// Clears all filters
    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        selectedColor = nil
        selectedSeason = nil
        selectedStyle = nil
        showFavoritesOnly = false
    }
    
    // MARK: - Analytics Helpers
    
    /// Gets most worn items (fetches from context)
    func getMostWornItems(limit: Int = 5, context: NSManagedObjectContext) -> [ItemEntity] {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.wearCount, ascending: false)]
        request.fetchLimit = limit
        return (try? context.fetch(request)) ?? []
    }
    
    /// Gets least worn items (fetches from context)
    func getLeastWornItems(limit: Int = 5, context: NSManagedObjectContext) -> [ItemEntity] {
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.wearCount, ascending: true)]
        request.fetchLimit = limit
        return (try? context.fetch(request)) ?? []
    }
}

