//
//  AIModels.swift
//  WardrobeAssistance_v1.1
//
//  Created by AI Assistant
//

import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let suggestedOutfit: [UUID]?

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), suggestedOutfit: [UUID]? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.suggestedOutfit = suggestedOutfit
    }
}

// MARK: - Filter Result

enum FilterResult {
    case wardrobeRelated
    case notRelated

    var isWardrobeRelated: Bool {
        switch self {
        case .wardrobeRelated: return true
        case .notRelated: return false
        }
    }
}

// MARK: - Response Source

enum ResponseSource {
    case local
    case ai(provider: AIProvider)
}

// MARK: - AI Response

struct AIResponse {
    let text: String
    let source: ResponseSource
    let suggestedOutfit: [UUID]?
    let reasoning: String?
}

// MARK: - Outfit Recommendation

struct OutfitRecommendation {
    let items: [UUID]
    let reasoning: String
    let score: Double
    let weatherSuitability: Double
    let colorHarmony: Double
    let styleConsistency: Double
}

// MARK: - AI Error

enum AIError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case rateLimitExceeded
    case invalidResponse
    case providerUnavailable
    case noItemsAvailable

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API ключ не настроен или недействителен"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Превышен лимит запросов. Попробуйте позже"
        case .invalidResponse:
            return "Получен некорректный ответ от AI"
        case .providerUnavailable:
            return "AI сервис временно недоступен"
        case .noItemsAvailable:
            return "Недостаточно вещей в гардеробе для создания образа"
        }
    }
}

// MARK: - AI Provider

enum AIProvider: String, Codable {
    case gemini
    case geminiProxy
    case yandexGPT

    var displayName: String {
        switch self {
        case .gemini:
            return "Gemini"
        case .geminiProxy:
            return "Gemini (Proxy)"
        case .yandexGPT:
            return "YandexGPT"
        }
    }
}

// MARK: - App Region

enum AppRegion {
    case russia
    case international

    var preferredProvider: AIProvider {
        switch self {
        case .russia:
            return .yandexGPT
        case .international:
            return .gemini
        }
    }
}

// MARK: - Style Preference

enum StylePreference: String, CaseIterable, Codable {
    case casual = "Casual"
    case formal = "Formal"
    case streetwear = "Streetwear"
    case business = "Business"
    case evening = "Evening"
    case sportswear = "Sportswear"
    case mixed = "Mixed"

    var localizedName: String {
        switch self {
        case .casual: return "Повседневный"
        case .formal: return "Формальный"
        case .streetwear: return "Уличный"
        case .business: return "Деловой"
        case .evening: return "Вечерний"
        case .sportswear: return "Спортивный"
        case .mixed: return "Смешанный"
        }
    }
}
