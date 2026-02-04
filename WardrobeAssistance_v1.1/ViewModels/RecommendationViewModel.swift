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
    @Published var stylePreference: StylePreference = .mixed

    private let wardrobeViewModel: WardrobeViewModel
    private let outfitViewModel: OutfitViewModel
    private let weatherService = WeatherService.shared
    private let engine = OutfitRecommendationEngine.shared
    private let aiService = AIStyleService.shared
    private let persistenceController = PersistenceController.shared

    init(wardrobeViewModel: WardrobeViewModel, outfitViewModel: OutfitViewModel) {
        self.wardrobeViewModel = wardrobeViewModel
        self.outfitViewModel = outfitViewModel

        Task {
            await loadWeather()
        }
    }

    // MARK: - Weather Integration

    func loadWeather() async {
        do {
            let weather = try await weatherService.fetchWeather()
            self.weatherData = weather
        } catch {
            print("Failed to load weather: \(error)")
            self.weatherData = createFallbackWeather()
        }
    }

    func refreshWeather() async {
        isLoading = true
        await loadWeather()
        isLoading = false

        // Regenerate recommendation with new weather
        generateDailyRecommendation()
    }

    private func createFallbackWeather() -> WeatherData {
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

        return WeatherData(
            temperature: temperature,
            condition: condition,
            humidity: Double.random(in: 30...80),
            windSpeed: Double.random(in: 0...20)
        )
    }

    // MARK: - Recommendation Generation

    func generateDailyRecommendation() {
        Task {
            isLoading = true
            aiErrorMessage = nil

            do {
                // Fetch all items
                let items = try await fetchAllItems()

                guard !items.isEmpty else {
                    aiErrorMessage = "Добавьте вещи в гардероб, чтобы получить рекомендации"
                    isLoading = false
                    return
                }

                // Ensure weather is loaded
                if weatherData == nil {
                    await loadWeather()
                }

                guard let weather = weatherData else {
                    aiErrorMessage = "Не удалось загрузить данные о погоде"
                    isLoading = false
                    return
                }

                // Generate outfit
                let response = try await aiService.generateOutfitRecommendation(
                    occasion: .casual,
                    weather: weather,
                    stylePreference: stylePreference,
                    items: items
                )

                await MainActor.run {
                    self.dailyRecommendation = response.suggestedOutfit
                    self.aiReasoning = response.reasoning
                    self.isLoading = false
                }

            } catch {
                await MainActor.run {
                    self.aiErrorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func generateOutfitForOccasion(_ occasion: Occasion) {
        Task {
            isLoading = true

            do {
                let items = try await fetchAllItems()

                guard let weather = weatherData else {
                    await loadWeather()
                    return
                }

                let response = try await aiService.generateOutfitRecommendation(
                    occasion: occasion,
                    weather: weather,
                    stylePreference: stylePreference,
                    items: items
                )

                await MainActor.run {
                    self.dailyRecommendation = response.suggestedOutfit
                    self.aiReasoning = response.reasoning
                    self.isLoading = false
                }

            } catch {
                await MainActor.run {
                    self.aiErrorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchAllItems() async throws -> [ItemEntity] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.dateAdded, ascending: false)]

        return try context.fetch(request)
    }
}
