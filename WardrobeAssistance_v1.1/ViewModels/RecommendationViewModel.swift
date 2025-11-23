//
//  RecommendationViewModel.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import SwiftUI
import CoreData
import Combine

/// ViewModel for outfit recommendations
@MainActor
class RecommendationViewModel: ObservableObject {
    @Published var dailyRecommendation: [UUID]?
    @Published var weatherData: WeatherData?
    @Published var isLoading: Bool = false
    @Published var aiReasoning: String?
    @Published var aiErrorMessage: String?
    
    private let wardrobeViewModel: WardrobeViewModel
    private let outfitViewModel: OutfitViewModel
    
    init(wardrobeViewModel: WardrobeViewModel, outfitViewModel: OutfitViewModel) {
        self.wardrobeViewModel = wardrobeViewModel
        self.outfitViewModel = outfitViewModel
        loadMockWeatherData()
    }
    
    // MARK: - Weather Integration
    
    func loadMockWeatherData() {
        // In a real app, this would fetch from a weather API
        // For now, we'll use mock data based on current season
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        
        var temperature: Double = 20.0
        var condition: WeatherCondition = .sunny
        
        switch month {
        case 12, 1, 2: // Winter
            temperature = Double.random(in: -5...10)
            condition = [.cloudy, .snowy, .windy].randomElement() ?? .cloudy
        case 3, 4, 5: // Spring
            temperature = Double.random(in: 10...20)
            condition = [.sunny, .cloudy, .rainy].randomElement() ?? .sunny
        case 6, 7, 8: // Summer
            temperature = Double.random(in: 20...35)
            condition = [.sunny, .cloudy].randomElement() ?? .sunny
        case 9, 10, 11: // Fall
            temperature = Double.random(in: 5...20)
            condition = [.cloudy, .rainy, .windy].randomElement() ?? .cloudy
        default:
            break
        }
        
        weatherData = WeatherData(
            temperature: temperature,
            condition: condition,
            humidity: Double.random(in: 30...80),
            windSpeed: Double.random(in: 0...20)
        )
    }
    
    // MARK: - Daily Recommendation
    
    func generateDailyRecommendation() {
        isLoading = true
        aiReasoning = nil
        aiErrorMessage = nil
        
        Task {
            let context = PersistenceController.shared.viewContext
            let occasion = getRecommendedOccasion()
            let fallbackSeason = weatherData?.recommendedSeason ?? .allSeason
            
            // Try to generate recommendation using outfit view model
            if let recommendation = outfitViewModel.generateOutfitRecommendation(
                occasion: occasion,
                season: fallbackSeason,
                weather: weatherData,
                context: context
            ) {
                await MainActor.run {
                    self.dailyRecommendation = recommendation
                    self.aiReasoning = "Подобран образ для \(occasion.rawValue) с учётом погоды"
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.aiErrorMessage = "Не удалось подобрать образ. Добавьте больше вещей в гардероб."
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getRecommendedOccasion() -> Occasion {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Simple logic: work hours = work, evening = casual/date, etc.
        switch hour {
        case 8...17:
            return .work
        case 18...20:
            return [.date, .casual].randomElement() ?? .casual
        default:
            return .casual
        }
    }
    
    // MARK: - Smart Matching
    
    func getSmartMatchingItems(for item: ItemEntity, context: NSManagedObjectContext) -> [ItemEntity] {
        // Fetch all items except the current one
        guard let itemId = item.id else {
            return []
        }
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id != %@", itemId as CVarArg)
        let availableItems = (try? context.fetch(request)) ?? []
        
        var matches: [ItemEntity] = []
        
        // Find items that match in style and season
        for otherItem in availableItems {
            var score = 0
            
            // Style match
            if otherItem.styleEnum == item.styleEnum {
                score += 2
            }
            
            // Season match
            if otherItem.seasonEnum == item.seasonEnum || 
               otherItem.seasonEnum == .allSeason || 
               item.seasonEnum == .allSeason {
                score += 1
            }
            
            // Color compatibility (basic rules)
            if let itemColor = item.colorEnum, let otherColor = otherItem.colorEnum,
               areColorsCompatible(itemColor, otherColor) {
                score += 1
            }
            
            // Category compatibility
            if let itemCategory = item.categoryEnum, let otherCategory = otherItem.categoryEnum,
               areCategoriesCompatible(itemCategory, otherCategory) {
                score += 2
            }
            
            if score >= 3 {
                matches.append(otherItem)
            }
        }
        
        // Sort by wear count (prefer less worn items)
        return matches.sorted { ($0.wearCount) < ($1.wearCount) }
    }
    
    private func areColorsCompatible(_ color1: ClothingColor, _ color2: ClothingColor) -> Bool {
        // Basic color compatibility rules
        let neutralColors: Set<ClothingColor> = [.black, .white, .gray, .navy, .beige, .brown]
        
        if neutralColors.contains(color1) || neutralColors.contains(color2) {
            return true
        }
        
        // Complementary colors
        let complementaryPairs: [(ClothingColor, ClothingColor)] = [
            (.red, .green),
            (.blue, .orange),
            (.yellow, .purple)
        ]
        
        for (c1, c2) in complementaryPairs {
            if (color1 == c1 && color2 == c2) || (color1 == c2 && color2 == c1) {
                return true
            }
        }
        
        return color1 == color2
    }
    
    private func areCategoriesCompatible(_ cat1: ClothingCategory, _ cat2: ClothingCategory) -> Bool {
        // Tops go with bottoms, dresses are standalone, etc.
        switch (cat1, cat2) {
        case (.tops, .bottoms), (.bottoms, .tops):
            return true
        case (.dresses, _), (_, .dresses):
            return false // Dresses are standalone
        case (.shoes, _), (_, .shoes):
            return true // Shoes go with anything
        case (.accessories, _), (_, .accessories):
            return true // Accessories go with anything
        case (.outerwear, _), (_, .outerwear):
            return true // Outerwear goes with anything
        default:
            return false
        }
    }
}

