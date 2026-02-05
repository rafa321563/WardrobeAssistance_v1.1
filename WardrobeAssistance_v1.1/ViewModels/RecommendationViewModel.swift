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

/// State of the recommendation engine
enum RecommendationState: Equatable {
    case idle
    case authenticating
    case loading
    case rateLimited(remaining: Int)
    case networkError(String)
    case error(String)
    case success

    var isLoading: Bool {
        switch self {
        case .authenticating, .loading:
            return true
        default:
            return false
        }
    }
}

/// ViewModel for outfit recommendations
@MainActor
class RecommendationViewModel: ObservableObject {
    @Published var dailyRecommendation: [UUID]?
    @Published var weatherData: WeatherData?
    @Published var aiReasoning: String?
    @Published var aiErrorMessage: String?
    @Published var stylePreference: StylePreference = .mixed
    @Published private(set) var state: RecommendationState = .idle
    @Published private(set) var remainingAICalls: Int?

    /// Backward compatibility
    var isLoading: Bool {
        state.isLoading
    }

    private let wardrobeViewModel: WardrobeViewModel
    private let outfitViewModel: OutfitViewModel
    private let weatherService = WeatherService.shared
    private let engine = OutfitRecommendationEngine.shared
    private let localAIService = AIStyleService.shared
    private let supabaseAIService = SupabaseAIService.shared
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
        state = .loading
        await loadWeather()
        state = .idle

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
            await generateRecommendation(occasion: .casual)
        }
    }

    func generateOutfitForOccasion(_ occasion: Occasion) {
        Task {
            await generateRecommendation(occasion: occasion)
        }
    }

    private func generateRecommendation(occasion: Occasion) async {
        state = .authenticating
        aiErrorMessage = nil

        do {
            // Fetch all items
            let items = try await fetchAllItems()

            guard !items.isEmpty else {
                aiErrorMessage = "Добавьте вещи в гардероб, чтобы получить рекомендации"
                state = .error("No items")
                return
            }

            // Ensure weather is loaded
            if weatherData == nil {
                await loadWeather()
            }

            guard let weather = weatherData else {
                aiErrorMessage = "Не удалось загрузить данные о погоде"
                state = .error("No weather")
                return
            }

            state = .loading

            // Convert items to DTOs
            let itemDTOs = items.map { $0.toDTO() }
            let weatherDTO = weather.toDTO()

            // Try Supabase Edge Function first
            do {
                let response = try await supabaseAIService.generateOutfit(
                    items: itemDTOs,
                    occasion: occasion.rawValue,
                    weather: weatherDTO,
                    stylePreference: stylePreference.rawValue
                )

                // Update remaining calls
                if let remaining = response.remainingCalls {
                    remainingAICalls = remaining
                }

                // Convert suggested item IDs to UUIDs
                let suggestedOutfit = response.itemIds.compactMap { UUID(uuidString: $0) }

                dailyRecommendation = suggestedOutfit
                aiReasoning = response.displayText
                state = .success

            } catch let error as SupabaseAIError {
                await handleSupabaseError(error, occasion: occasion, weather: weather, items: items)
            }

        } catch {
            aiErrorMessage = error.localizedDescription
            state = .error(error.localizedDescription)
        }
    }

    private func handleSupabaseError(
        _ error: SupabaseAIError,
        occasion: Occasion,
        weather: WeatherData,
        items: [ItemEntity]
    ) async {
        switch error {
        case .rateLimited(let remaining, let message):
            state = .rateLimited(remaining: remaining)
            remainingAICalls = remaining
            aiErrorMessage = message
            // Fall back to local engine
            await fallbackToLocalEngine(occasion: occasion, weather: weather, items: items)

        case .unauthorized:
            // Clear credentials and show error
            AuthService.shared.clearCredentials()
            state = .error("Authentication required")
            aiErrorMessage = "Сессия истекла. Пожалуйста, попробуйте снова."

        case .networkError, .serverError:
            state = .networkError(error.localizedDescription)
            // Fall back to local engine
            await fallbackToLocalEngine(occasion: occasion, weather: weather, items: items)

        default:
            state = .error(error.localizedDescription)
            await fallbackToLocalEngine(occasion: occasion, weather: weather, items: items)
        }
    }

    private func fallbackToLocalEngine(
        occasion: Occasion,
        weather: WeatherData,
        items: [ItemEntity]
    ) async {
        do {
            let response = try await localAIService.generateOutfitRecommendation(
                occasion: occasion,
                weather: weather,
                stylePreference: stylePreference,
                items: items
            )

            dailyRecommendation = response.suggestedOutfit
            aiReasoning = (response.reasoning ?? "") + "\n\n(Сгенерировано локально)"

            // Keep the error state if rate limited, otherwise set to success
            if case .rateLimited = state {
                // Keep rate limited state
            } else {
                state = .success
            }

        } catch {
            aiErrorMessage = "Не удалось сгенерировать рекомендацию"
            state = .error(error.localizedDescription)
        }
    }

    private func fetchAllItems() async throws -> [ItemEntity] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.dateAdded, ascending: false)]

        return try context.fetch(request)
    }
}
