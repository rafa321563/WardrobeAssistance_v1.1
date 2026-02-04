//
//  OutfitRecommendationEngine.swift
//  WardrobeAssistance_v1.1
//
//  Created by AI Assistant
//

import Foundation
import CoreData

/// Local outfit recommendation engine with color matching and style rules
final class OutfitRecommendationEngine {
    static let shared = OutfitRecommendationEngine()

    private init() {}

    // MARK: - Public Methods

    /// Generates outfit recommendations based on parameters
    func generateOutfit(
        occasion: Occasion,
        weather: WeatherData,
        stylePreference: StylePreference?,
        items: [ItemEntity]
    ) -> OutfitRecommendation? {
        guard !items.isEmpty else { return nil }

        // Filter items by season/weather
        let seasonalItems = filterByWeather(items: items, weather: weather)
        guard !seasonalItems.isEmpty else { return nil }

        // Filter by occasion
        let occasionItems = filterByOccasion(items: seasonalItems, occasion: occasion)
        guard !occasionItems.isEmpty else { return nil }

        // Build outfit template based on occasion
        let template = getOutfitTemplate(occasion: occasion)

        // Select items for each category
        var selectedItems: [ItemEntity] = []
        for category in template.requiredCategories {
            if let item = selectBestItem(
                from: occasionItems,
                category: category,
                stylePreference: stylePreference,
                existing: selectedItems
            ) {
                selectedItems.append(item)
            }
        }

        guard selectedItems.count >= template.minimumItems else { return nil }

        // Calculate scores
        let colorScore = calculateColorHarmony(items: selectedItems)
        let weatherScore = calculateWeatherSuitability(items: selectedItems, weather: weather)
        let styleScore = calculateStyleConsistency(items: selectedItems)

        let overallScore = (colorScore + weatherScore + styleScore) / 3.0

        let reasoning = generateReasoning(
            items: selectedItems,
            occasion: occasion,
            weather: weather,
            colorScore: colorScore,
            weatherScore: weatherScore,
            styleScore: styleScore
        )

        return OutfitRecommendation(
            items: selectedItems.compactMap { $0.id },
            reasoning: reasoning,
            score: overallScore,
            weatherSuitability: weatherScore,
            colorHarmony: colorScore,
            styleConsistency: styleScore
        )
    }

    // MARK: - Filtering Methods

    private func filterByWeather(items: [ItemEntity], weather: WeatherData) -> [ItemEntity] {
        let recommendedSeason = weather.recommendedSeason

        return items.filter { item in
            guard let itemSeasonStr = item.season,
                  let itemSeason = Season(rawValue: itemSeasonStr) else {
                return true
            }

            return itemSeason == recommendedSeason || itemSeason == .allSeason
        }
    }

    private func filterByOccasion(items: [ItemEntity], occasion: Occasion) -> [ItemEntity] {
        let styleMap: [Occasion: [Style]] = [
            .work: [.business, .formal, .casual],
            .casual: [.casual, .streetwear],
            .date: [.evening, .casual, .formal],
            .sports: [.sportswear],
            .party: [.evening, .casual, .streetwear],
            .formal: [.formal, .business, .evening],
            .travel: [.casual, .sportswear],
            .home: [.casual, .sportswear]
        ]

        let preferredStyles = styleMap[occasion] ?? [.casual]

        return items.filter { item in
            guard let itemStyleStr = item.style,
                  let itemStyle = Style(rawValue: itemStyleStr) else {
                return true
            }

            return preferredStyles.contains(itemStyle)
        }
    }

    // MARK: - Outfit Templates

    private struct OutfitTemplate {
        let requiredCategories: [ClothingCategory]
        let minimumItems: Int
    }

    private func getOutfitTemplate(occasion: Occasion) -> OutfitTemplate {
        switch occasion {
        case .work, .formal:
            return OutfitTemplate(
                requiredCategories: [.tops, .bottoms, .shoes, .outerwear, .accessories],
                minimumItems: 3
            )
        case .date, .party:
            return OutfitTemplate(
                requiredCategories: [.dresses, .tops, .bottoms, .shoes, .accessories],
                minimumItems: 2
            )
        case .sports:
            return OutfitTemplate(
                requiredCategories: [.activewear, .shoes],
                minimumItems: 2
            )
        case .casual, .travel, .home:
            return OutfitTemplate(
                requiredCategories: [.tops, .bottoms, .shoes],
                minimumItems: 2
            )
        }
    }

    // MARK: - Item Selection

    private func selectBestItem(
        from items: [ItemEntity],
        category: ClothingCategory,
        stylePreference: StylePreference?,
        existing: [ItemEntity]
    ) -> ItemEntity? {
        let categoryItems = items.filter { item in
            guard let itemCategory = item.category,
                  let cat = ClothingCategory(rawValue: itemCategory) else {
                return false
            }
            return cat == category
        }

        guard !categoryItems.isEmpty else { return nil }

        // Score each item
        let scored = categoryItems.map { item -> (item: ItemEntity, score: Double) in
            var score = 0.0

            // Prefer favorites
            if item.isFavorite {
                score += 2.0
            }

            // Prefer frequently worn items
            score += min(Double(item.wearCount) * 0.1, 2.0)

            // Color harmony with existing items
            if !existing.isEmpty {
                score += calculateColorCompatibility(item: item, with: existing)
            }

            // Style preference match
            if let stylePreference = stylePreference,
               let itemStyle = item.style,
               let style = Style(rawValue: itemStyle) {
                if style.rawValue == stylePreference.rawValue {
                    score += 3.0
                }
            }

            return (item, score)
        }

        return scored.max(by: { $0.score < $1.score })?.item
    }

    // MARK: - Scoring Methods

    private func calculateColorHarmony(items: [ItemEntity]) -> Double {
        guard items.count > 1 else { return 1.0 }

        var totalScore = 0.0
        var comparisons = 0

        for i in 0..<items.count {
            for j in (i+1)..<items.count {
                if let color1 = items[i].color, let c1 = ClothingColor(rawValue: color1),
                   let color2 = items[j].color, let c2 = ClothingColor(rawValue: color2) {
                    totalScore += colorHarmonyScore(c1, c2)
                    comparisons += 1
                }
            }
        }

        return comparisons > 0 ? totalScore / Double(comparisons) : 0.5
    }

    private func colorHarmonyScore(_ c1: ClothingColor, _ c2: ClothingColor) -> Double {
        // Neutral colors match everything
        let neutrals: Set<ClothingColor> = [.black, .white, .gray, .beige, .navy]
        if neutrals.contains(c1) || neutrals.contains(c2) {
            return 1.0
        }

        // Same color
        if c1 == c2 {
            return 0.8
        }

        // Complementary pairs
        let complementary: [(ClothingColor, ClothingColor)] = [
            (.blue, .orange), (.red, .green), (.yellow, .purple),
            (.pink, .green), (.blue, .yellow)
        ]

        for (a, b) in complementary {
            if (c1 == a && c2 == b) || (c1 == b && c2 == a) {
                return 0.9
            }
        }

        // Analogous colors
        let analogous: [(ClothingColor, ClothingColor)] = [
            (.blue, .purple), (.blue, .green), (.red, .orange),
            (.red, .pink), (.yellow, .orange), (.yellow, .green)
        ]

        for (a, b) in analogous {
            if (c1 == a && c2 == b) || (c1 == b && c2 == a) {
                return 0.85
            }
        }

        return 0.6
    }

    private func calculateColorCompatibility(item: ItemEntity, with existing: [ItemEntity]) -> Double {
        guard let itemColor = item.color,
              let color = ClothingColor(rawValue: itemColor) else {
            return 0.5
        }

        var totalScore = 0.0
        for existingItem in existing {
            if let existingColor = existingItem.color,
               let eColor = ClothingColor(rawValue: existingColor) {
                totalScore += colorHarmonyScore(color, eColor)
            }
        }

        return existing.isEmpty ? 0.5 : totalScore / Double(existing.count)
    }

    private func calculateWeatherSuitability(items: [ItemEntity], weather: WeatherData) -> Double {
        let recommendedSeason = weather.recommendedSeason
        var suitableCount = 0

        for item in items {
            guard let itemSeasonStr = item.season,
                  let itemSeason = Season(rawValue: itemSeasonStr) else {
                continue
            }

            if itemSeason == recommendedSeason || itemSeason == .allSeason {
                suitableCount += 1
            }
        }

        return Double(suitableCount) / Double(items.count)
    }

    private func calculateStyleConsistency(items: [ItemEntity]) -> Double {
        let styles = items.compactMap { item -> Style? in
            guard let styleStr = item.style else { return nil }
            return Style(rawValue: styleStr)
        }

        guard !styles.isEmpty else { return 0.5 }

        let styleCounts = Dictionary(grouping: styles, by: { $0 }).mapValues { $0.count }
        let maxCount = styleCounts.values.max() ?? 0

        return Double(maxCount) / Double(styles.count)
    }

    // MARK: - Reasoning Generation

    private func generateReasoning(
        items: [ItemEntity],
        occasion: Occasion,
        weather: WeatherData,
        colorScore: Double,
        weatherScore: Double,
        styleScore: Double
    ) -> String {
        var parts: [String] = []

        // Weather reasoning
        if weather.isCold {
            parts.append("Учитывая холодную погоду (\(Int(weather.temperature))°C)")
        } else if weather.isHot {
            parts.append("Для жаркой погоды (\(Int(weather.temperature))°C)")
        } else {
            parts.append("При комфортной температуре (\(Int(weather.temperature))°C)")
        }

        // Occasion reasoning
        switch occasion {
        case .work:
            parts.append("подобран деловой образ")
        case .date:
            parts.append("создан романтичный образ")
        case .casual:
            parts.append("составлен повседневный комплект")
        case .sports:
            parts.append("выбрана спортивная одежда")
        case .party:
            parts.append("подготовлен праздничный наряд")
        case .formal:
            parts.append("сформирован формальный стиль")
        case .travel:
            parts.append("собран комфортный образ для путешествия")
        case .home:
            parts.append("выбрана домашняя одежда")
        }

        // Color reasoning
        if colorScore > 0.8 {
            parts.append("с отличным сочетанием цветов")
        } else if colorScore > 0.6 {
            parts.append("с гармоничной цветовой гаммой")
        }

        // Style reasoning
        if styleScore > 0.8 {
            parts.append("в едином стиле")
        }

        return parts.joined(separator: ", ") + "."
    }
}
