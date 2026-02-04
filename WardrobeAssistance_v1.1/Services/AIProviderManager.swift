//
//  AIProviderManager.swift
//  WardrobeAssistance_v1.1
//
//  Created by AI Assistant
//

import Foundation

/// AI provider manager with Gemini and YandexGPT support
actor AIProviderManager {
    static let shared = AIProviderManager()

    private var region: AppRegion?
    private var requestCount: Int = 0
    private var lastResetDate: Date = Date()
    private let dailyLimit = 1000

    private init() {}

    // MARK: - Public Methods

    /// Gets AI response for a chat message
    func getAIResponse(
        message: String,
        history: [ChatMessage],
        context: String?
    ) async throws -> String {
        // Check rate limit
        try checkRateLimit()

        // Detect region if not already detected
        if region == nil {
            await detectRegion()
        }

        let provider = region?.preferredProvider ?? .gemini

        do {
            let response = try await sendRequest(
                message: message,
                history: history,
                context: context,
                provider: provider
            )

            requestCount += 1
            return response
        } catch {
            // Try fallback provider
            let fallbackProvider: AIProvider = provider == .gemini ? .yandexGPT : .gemini

            do {
                let response = try await sendRequest(
                    message: message,
                    history: history,
                    context: context,
                    provider: fallbackProvider
                )

                requestCount += 1
                return response
            } catch {
                throw AIError.providerUnavailable
            }
        }
    }

    // MARK: - Private Methods

    private func detectRegion() async {
        // First, check locale
        let locale = Locale.current
        if locale.language.languageCode?.identifier == "ru" {
            region = .russia
            return
        }

        // Try to detect by IP (using free ipapi.co service)
        do {
            guard let url = URL(string: "https://ipapi.co/json/") else {
                region = .international
                return
            }

            let (data, _) = try await URLSession.shared.data(from: url)

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let countryCode = json["country_code"] as? String {
                region = countryCode == "RU" ? .russia : .international
            } else {
                region = .international
            }
        } catch {
            region = .international
        }
    }

    private func checkRateLimit() throws {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            requestCount = 0
            lastResetDate = Date()
        }

        guard requestCount < dailyLimit else {
            throw AIError.rateLimitExceeded
        }
    }

    private func sendRequest(
        message: String,
        history: [ChatMessage],
        context: String?,
        provider: AIProvider
    ) async throws -> String {
        switch provider {
        case .gemini:
            return try await sendGeminiRequest(message: message, history: history, context: context)
        case .geminiProxy:
            return try await sendGeminiProxyRequest(message: message, history: history, context: context)
        case .yandexGPT:
            return try await sendYandexGPTRequest(message: message, history: history, context: context)
        }
    }

    // MARK: - Gemini API

    private func sendGeminiRequest(
        message: String,
        history: [ChatMessage],
        context: String?
    ) async throws -> String {
        guard let apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
              !apiKey.isEmpty,
              !apiKey.starts(with: "YOUR_") else {
            throw AIError.invalidAPIKey
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw AIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build prompt
        var fullPrompt = ""
        if let context = context {
            fullPrompt += "Контекст: \(context)\n\n"
        }

        if !history.isEmpty {
            fullPrompt += "История:\n"
            for msg in history.suffix(5) {
                fullPrompt += "\(msg.role == .user ? "Пользователь" : "Ассистент"): \(msg.content)\n"
            }
            fullPrompt += "\n"
        }

        fullPrompt += "Сообщение: \(message)"

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": fullPrompt]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text
    }

    private func sendGeminiProxyRequest(
        message: String,
        history: [ChatMessage],
        context: String?
    ) async throws -> String {
        // Placeholder for proxy implementation
        throw AIError.providerUnavailable
    }

    // MARK: - YandexGPT API

    private func sendYandexGPTRequest(
        message: String,
        history: [ChatMessage],
        context: String?
    ) async throws -> String {
        guard let apiKey = Bundle.main.infoDictionary?["YANDEX_API_KEY"] as? String,
              !apiKey.isEmpty,
              !apiKey.starts(with: "YOUR_") else {
            throw AIError.invalidAPIKey
        }

        guard let folderId = Bundle.main.infoDictionary?["YANDEX_FOLDER_ID"] as? String,
              !folderId.isEmpty,
              !folderId.starts(with: "YOUR_") else {
            throw AIError.invalidAPIKey
        }

        let urlString = "https://llm.api.cloud.yandex.net/foundationModels/v1/completion"

        guard let url = URL(string: urlString) else {
            throw AIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(folderId, forHTTPHeaderField: "x-folder-id")

        // Build messages array
        var messages: [[String: Any]] = []

        if let context = context {
            messages.append([
                "role": "system",
                "text": context
            ])
        }

        for msg in history.suffix(5) {
            messages.append([
                "role": msg.role == .user ? "user" : "assistant",
                "text": msg.content
            ])
        }

        messages.append([
            "role": "user",
            "text": message
        ])

        let body: [String: Any] = [
            "modelUri": "gpt://\(folderId)/yandexgpt-lite",
            "completionOptions": [
                "stream": false,
                "temperature": 0.7,
                "maxTokens": 2000
            ],
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let alternatives = result["alternatives"] as? [[String: Any]],
              let firstAlternative = alternatives.first,
              let message = firstAlternative["message"] as? [String: Any],
              let text = message["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text
    }
}
