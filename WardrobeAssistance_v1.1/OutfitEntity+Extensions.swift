//
//  OutfitEntity+Extensions.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import CoreData
import UIKit
import SwiftUI

extension OutfitEntity {
    
    // MARK: - Enum Computed Properties
    
    /// Returns the occasion as an Occasion enum, or nil if invalid
    var occasionEnum: Occasion? {
        get {
            guard let occasionString = occasion else { return nil }
            return Occasion(rawValue: occasionString)
        }
        set {
            occasion = newValue?.rawValue
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
    
    // MARK: - Items Array Conversion
    
    /// Returns items as an array of UUIDs
    var itemsArray: [UUID] {
        get {
            // Core Data Transformable with customClassName="[UUID]" stores directly as [UUID]?
            // items property is already of type [UUID]? from Core Data
            return items ?? []
        }
        set {
            // Store directly as [UUID] for Core Data Transformable
            items = newValue
        }
    }
    
    // MARK: - Image Loading
    
    /// Returns a SwiftUI Image from the stored imageData
    var swiftUIImage: Image? {
        guard let imageData = imageData,
              let uiImage = UIImage(data: imageData) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    /// Returns a UIImage from the stored imageData
    var uiImage: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    // MARK: - Convenience Properties
    
    /// Safe name access with fallback
    var displayName: String {
        name ?? "Unnamed Outfit"
    }
    
    /// Safe occasion access with fallback
    var displayOccasion: Occasion {
        occasionEnum ?? .casual
    }
    
    /// Safe season access with fallback
    var displaySeason: Season {
        seasonEnum ?? .allSeason
    }
    
    // MARK: - Wear Count Management
    
    /// Marks the outfit as worn (increments count and updates lastWorn date)
    func markAsWorn() {
        wearCount += 1
        lastWorn = Date()
    }
}

