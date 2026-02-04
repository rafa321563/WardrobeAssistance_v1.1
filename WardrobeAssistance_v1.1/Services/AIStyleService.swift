//
//  AIStyleService.swift
//  WardrobeAssistance_v1.1
//
//  Created by AI Assistant
//

import Foundation
import CoreData

/// Main AI style service combining topic filtering, local engine, and AI providers
final class AIStyleService {
    static let shared = AIStyleService()

    private let topicFilter = TopicFilter.shared
    private let engine = OutfitRecommendationEngine.shared
    private let providerManager = AIProviderManager.shared

    private init() {}

    // MARK: - Public Methods

    /// Gets AI response for a user message
    func getResponse(
        message: String,
        history: [ChatMessage],
        items: [ItemEntity]
    ) async throws -> AIResponse {
        // Filter message
        let filterResult = topicFilter.filter(message: message)

        guard filterResult.isWardrobeRelated else {
            return AIResponse(
                text: "Извините, я специализируюсь только на вопросах, связанных с гардеробом и стилем. Пожалуйста, задайте вопрос о вашей одежде, образах или моде.",
                source: .local,
                suggestedOutfit: nil,
                reasoning: nil
            )
        }

        // Check if user is asking for outfit recommendation
        if isRequestingOutfit(message: message) {
            return try await generateOutfitRecommendation(
                message: message,
                items: items,
                history: history
            )
        }

        // Get AI response for general fashion question
        do {
            let context = buildContext(items: items)
            let aiText = try await providerManager.getAIResponse(
                message: message,
                history: history,
                context: context
            )

            return AIResponse(
                text: aiText,
                source: .ai(provider: .gemini),
                suggestedOutfit: nil,
                reasoning: nil
            )
        } catch {
            // Fallback to local response
            return AIResponse(
                text: generateLocalResponse(message: message, items: items),
                source: .local,
                suggestedOutfit: nil,
                reasoning: nil
            )
        }
    }

    /// Generates outfit recommendation for specific request
    func generateOutfitRecommendation(
        occasion: Occasion,
        weather: WeatherData,
        stylePreference: StylePreference?,
        items: [ItemEntity]
    ) async throws -> AIResponse {
        guard let recommendation = engine.generateOutfit(
            occasion: occasion,
            weather: weather,
            stylePreference: stylePreference,
            items: items
        ) else {
            throw AIError.noItemsAvailable
        }

        return AIResponse(
            text: recommendation.reasoning,
            source: .local,
            suggestedOutfit: recommendation.items,
            reasoning: recommendation.reasoning
        )
    }

    // MARK: - Private Methods

    private func isRequestingOutfit(message: String) -> Bool {
        let lowercased = message.lowercased()
        let outfitKeywords = [
            "подбери", "подобрать", "что надеть", "что носить", "образ",
            "комплект", "аутфит", "outfit", "recommend", "suggest",
            "на сегодня", "на работу", "на свидание", "на вечеринку"
        ]

        return outfitKeywords.contains { lowercased.contains($0) }
    }

    private func generateOutfitRecommendation(
        message: String,
        items: [ItemEntity],
        history: [ChatMessage]
    ) async throws -> AIResponse {
        // Parse message to extract occasion
        let occasion = extractOccasion(from: message)

        // Get current weather
        let weather = try await WeatherService.shared.fetchWeather()

        // Extract style preference if mentioned
        let stylePreference = extractStylePreference(from: message)

        guard let recommendation = engine.generateOutfit(
            occasion: occasion,
            weather: weather,
            stylePreference: stylePreference,
            items: items
        ) else {
            throw AIError.noItemsAvailable
        }

        // Enhance reasoning with AI if available
        var finalText = recommendation.reasoning

        do {
            let context = "Гардероб: \(items.count) вещей. Погода: \(Int(weather.temperature))°C, \(weather.condition.rawValue)."
            let enhancedText = try await providerManager.getAIResponse(
                message: "Объясни этот образ: \(recommendation.reasoning)",
                history: [],
                context: context
            )
            finalText = enhancedText
        } catch {
            // Use local reasoning if AI fails
        }

        return AIResponse(
            text: finalText,
            source: .local,
            suggestedOutfit: recommendation.items,
            reasoning: recommendation.reasoning
        )
    }

    private func extractOccasion(from message: String) -> Occasion {
        let lowercased = message.lowercased()

        if lowercased.contains("работ") || lowercased.contains("офис") {
            return .work
        } else if lowercased.contains("свидание") || lowercased.contains("романтик") {
            return .date
        } else if lowercased.contains("вечеринк") || lowercased.contains("праздник") {
            return .party
        } else if lowercased.contains("спорт") || lowercased.contains("трениров") {
            return .sports
        } else if lowercased.contains("формальн") || lowercased.contains("официальн") {
            return .formal
        } else if lowercased.contains("путешеств") || lowercased.contains("поездк") {
            return .travel
        } else if lowercased.contains("дом") {
            return .home
        }

        return .casual
    }

    private func extractStylePreference(from message: String) -> StylePreference? {
        let lowercased = message.lowercased()

        for preference in StylePreference.allCases {
            if lowercased.contains(preference.rawValue.lowercased()) ||
               lowercased.contains(preference.localizedName.lowercased()) {
                return preference
            }
        }

        return nil
    }

    private func buildContext(items: [ItemEntity]) -> String {
        let categoryCounts = Dictionary(grouping: items, by: { $0.category ?? "Unknown" })
            .mapValues { $0.count }

        var context = "Гардероб пользователя содержит \(items.count) вещей: "
        let counts = categoryCounts.map { "\($0.value) \($0.key)" }.joined(separator: ", ")
        context += counts + "."

        return context
    }

    private func generateLocalResponse(message: String, items: [ItemEntity]) -> String {
        let responses = [
            "Отличный вопрос о стиле! В вашем гардеробе \(items.count) вещей, которые можно сочетать по-разному.",
            "Интересно! Давайте подумаем, как можно использовать вещи из вашего гардероба.",
            "Хороший вопрос! У вас есть несколько вариантов, учитывая ваш гардероб.",
            "Это зависит от многих факторов. Расскажите больше о ситуации, и я помогу подобрать образ."
        ]

        return responses.randomElement() ?? responses[0]
    }
}
