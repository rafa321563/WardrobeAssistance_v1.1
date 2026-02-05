//
//  SupabaseAIService.swift
//  WardrobeAssistance_v1.1
//
//  Supabase Edge Function client for AI outfit recommendations
//

import Foundation

/// Service for calling Supabase Edge Functions for AI recommendations
final class SupabaseAIService {
    static let shared = SupabaseAIService()

    // MARK: - Configuration

    private let supabaseURL = "https://lqpmgnfjwlecgxecuqtg.supabase.co"
    private let authService = AuthService.shared

    private init() {}

    // MARK: - Public Methods

    /// Generates an outfit recommendation via Supabase Edge Function
    func generateOutfit(
        items: [WardrobeItemDTO],
        occasion: String,
        weather: WeatherDTO?,
        stylePreference: String?
    ) async throws -> OutfitRecommendationResponse {
        let token = try await authService.getValidToken()

        let url = URL(string: "\(supabaseURL)/functions/v1/generate-outfit")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let requestBody = OutfitRequestBody(
            items: items,
            occasion: occasion,
            weather: weather,
            stylePreference: stylePreference
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(OutfitRecommendationResponse.self, from: data)

        case 401:
            throw SupabaseAIError.unauthorized

        case 429:
            // Rate limited - parse error for details
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SupabaseAIError.rateLimited(
                    remaining: errorResponse.remainingCalls ?? 0,
                    message: errorResponse.error ?? "Rate limit exceeded"
                )
            }
            throw SupabaseAIError.rateLimited(remaining: 0, message: "Rate limit exceeded")

        case 500...599:
            throw SupabaseAIError.serverError(statusCode: httpResponse.statusCode)

        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseAIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
    }

    /// Sends a chat message to the AI stylist
    func sendChatMessage(
        message: String,
        history: [ChatMessageDTO],
        items: [WardrobeItemDTO]
    ) async throws -> ChatResponse {
        let token = try await authService.getValidToken()

        let url = URL(string: "\(supabaseURL)/functions/v1/generate-outfit")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let requestBody = ChatRequestBody(
            message: message,
            history: history,
            items: items
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(ChatResponse.self, from: data)

        case 401:
            throw SupabaseAIError.unauthorized

        case 429:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SupabaseAIError.rateLimited(
                    remaining: errorResponse.remainingCalls ?? 0,
                    message: errorResponse.error ?? "Rate limit exceeded"
                )
            }
            throw SupabaseAIError.rateLimited(remaining: 0, message: "Rate limit exceeded")

        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseAIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
    }
}

// MARK: - Request DTOs

struct WardrobeItemDTO: Codable {
    let id: String
    let name: String
    let category: String
    let color: String
    let season: String
    let style: String
    let brand: String?
    let material: String?
    let tags: [String]?
    let wearCount: Int
    let isFavorite: Bool
}

struct WeatherDTO: Codable {
    let temperature: Double
    let condition: String
    let humidity: Double
    let windSpeed: Double
}

struct OutfitRequestBody: Codable {
    let items: [WardrobeItemDTO]
    let occasion: String
    let weather: WeatherDTO?
    let stylePreference: String?
}

struct ChatMessageDTO: Codable {
    let role: String
    let content: String
}

struct ChatRequestBody: Codable {
    let message: String
    let history: [ChatMessageDTO]
    let items: [WardrobeItemDTO]
}

// MARK: - Response DTOs

struct OutfitRecommendationResponse: Codable {
    let suggestedItems: [String]?  // Array of item UUIDs (optional for error cases)
    let reasoning: String?
    let text: String?
    let score: Double?
    let weatherSuitability: Double?
    let colorHarmony: Double?
    let styleConsistency: Double?
    let remainingCalls: Int?

    var itemIds: [String] {
        suggestedItems ?? []
    }

    var displayText: String {
        reasoning ?? text ?? ""
    }
}

struct ChatResponse: Codable {
    let text: String
    let suggestedItems: [String]?
    let reasoning: String?
    let remainingCalls: Int?
}

struct ErrorResponse: Codable {
    let error: String?
    let remainingCalls: Int?
    let message: String?
}

// MARK: - Errors

enum SupabaseAIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited(remaining: Int, message: String)
    case serverError(statusCode: Int)
    case requestFailed(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required"
        case .rateLimited(_, let message):
            return message
        case .serverError(let code):
            return "Server error (\(code))"
        case .requestFailed(let code, let message):
            return "Request failed (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    var isRateLimited: Bool {
        if case .rateLimited = self {
            return true
        }
        return false
    }
}

// MARK: - ItemEntity to DTO Conversion

extension ItemEntity {
    func toDTO() -> WardrobeItemDTO {
        WardrobeItemDTO(
            id: id?.uuidString ?? UUID().uuidString,
            name: name ?? "Unknown",
            category: category ?? "Tops",
            color: color ?? "Black",
            season: season ?? "All Season",
            style: style ?? "Casual",
            brand: brand,
            material: material,
            tags: tagsArray.isEmpty ? nil : tagsArray,
            wearCount: Int(wearCount),
            isFavorite: isFavorite
        )
    }
}

extension WeatherData {
    func toDTO() -> WeatherDTO {
        WeatherDTO(
            temperature: temperature,
            condition: condition.rawValue,
            humidity: humidity,
            windSpeed: windSpeed
        )
    }
}

extension ChatMessage {
    func toDTO() -> ChatMessageDTO {
        ChatMessageDTO(
            role: role.rawValue,
            content: content
        )
    }
}
