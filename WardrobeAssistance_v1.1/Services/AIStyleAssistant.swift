//
//  AIStyleAssistant.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import SwiftUI
import Combine
import CoreData

/// State of the AI assistant
enum AIAssistantState: Equatable {
    case idle
    case authenticating
    case processing
    case rateLimited(remaining: Int)
    case networkError(String)
    case error(String)

    var isLoading: Bool {
        switch self {
        case .authenticating, .processing:
            return true
        default:
            return false
        }
    }
}

@MainActor
final class AIStyleAssistant: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var state: AIAssistantState = .idle
    @Published private(set) var errorMessage: String?
    @Published private(set) var remainingCalls: Int?

    private weak var wardrobeViewModel: WardrobeViewModel?
    private let supabaseService = SupabaseAIService.shared
    private let localService = AIStyleService.shared
    private let topicFilter = TopicFilter.shared
    private let persistenceController = PersistenceController.shared

    /// Backward compatibility
    var isProcessing: Bool {
        state.isLoading
    }

    init(wardrobeViewModel: WardrobeViewModel) {
        self.wardrobeViewModel = wardrobeViewModel

        messages.append(
            ChatMessage(
                role: .assistant,
                content: "Привет! Я твой персональный AI-стилист. 👗\n\nСпроси меня:\n• Что надеть на сегодня\n• Как подобрать образ\n• Что сочетается с моими вещами\n\nИли выбери быстрое действие ниже ⬇️",
                timestamp: Date(),
                suggestedOutfit: nil
            )
        )
    }

    // MARK: - Public Methods

    func send(message: String) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        errorMessage = nil
        let userMessage = ChatMessage(role: .user, content: message, timestamp: Date())
        messages.append(userMessage)

        Task {
            await process(message: message)
        }
    }

    func requestDailyOutfit() {
        send(message: "Подбери мне образ на сегодня")
    }

    func requestWorkOutfit() {
        send(message: "Что надеть на работу?")
    }

    func requestDateOutfit() {
        send(message: "Подбери образ на свидание")
    }

    func requestTrends() {
        send(message: "Какие сейчас актуальные тренды?")
    }

    // MARK: - Private Methods

    private func process(message: String) async {
        guard !state.isLoading else { return }

        // First, filter the message locally
        let filterResult = topicFilter.filter(message: message)

        guard filterResult.isWardrobeRelated else {
            let response = ChatMessage(
                role: .assistant,
                content: "Извините, я специализируюсь только на вопросах, связанных с гардеробом и стилем. Пожалуйста, задайте вопрос о вашей одежде, образах или моде.",
                timestamp: Date(),
                suggestedOutfit: nil
            )
            messages.append(response)
            return
        }

        state = .authenticating

        do {
            // Fetch all items from wardrobe
            let items = try await fetchAllItems()

            guard !items.isEmpty else {
                await showError("Добавьте вещи в гардероб, чтобы получить рекомендации")
                return
            }

            state = .processing

            // Convert items to DTOs
            let itemDTOs = items.map { $0.toDTO() }
            let historyDTOs = Array(messages.suffix(10)).map { $0.toDTO() }

            // Call Supabase Edge Function
            let response = try await supabaseService.sendChatMessage(
                message: message,
                history: historyDTOs,
                items: itemDTOs
            )

            // Update remaining calls
            if let remaining = response.remainingCalls {
                remainingCalls = remaining
            }

            // Convert suggested item IDs to UUIDs
            let suggestedOutfit = response.suggestedItems?.compactMap { UUID(uuidString: $0) }

            // Create assistant message
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response.text,
                timestamp: Date(),
                suggestedOutfit: suggestedOutfit
            )

            messages.append(assistantMessage)
            state = .idle
            errorMessage = nil

        } catch let error as SupabaseAIError {
            await handleSupabaseError(error, message: message)
        } catch let error as AuthError {
            state = .networkError(error.localizedDescription)
            await showError("Ошибка аутентификации. Попробуйте позже.")
        } catch {
            state = .networkError(error.localizedDescription)
            await fallbackToLocalProcessing(message: message)
        }
    }

    private func handleSupabaseError(_ error: SupabaseAIError, message: String) async {
        switch error {
        case .rateLimited(let remaining, let msg):
            state = .rateLimited(remaining: remaining)
            remainingCalls = remaining
            await showError(msg)

        case .unauthorized:
            // Clear credentials and retry
            AuthService.shared.clearCredentials()
            state = .error("Требуется повторная аутентификация")
            await showError("Сессия истекла. Пожалуйста, попробуйте снова.")

        case .networkError, .serverError:
            state = .networkError(error.localizedDescription)
            await fallbackToLocalProcessing(message: message)

        default:
            state = .error(error.localizedDescription)
            await fallbackToLocalProcessing(message: message)
        }
    }

    private func fallbackToLocalProcessing(message: String) async {
        do {
            let items = try await fetchAllItems()

            let response = try await localService.getResponse(
                message: message,
                history: Array(messages.suffix(10)),
                items: items
            )

            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response.text + "\n\n(Ответ сгенерирован локально)",
                timestamp: Date(),
                suggestedOutfit: response.suggestedOutfit
            )

            messages.append(assistantMessage)
            state = .idle

        } catch {
            await showError("Не удалось получить ответ. Попробуйте позже.")
        }
    }

    private func fetchAllItems() async throws -> [ItemEntity] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<ItemEntity> = ItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.dateAdded, ascending: false)]

        return try context.fetch(request)
    }

    private func showError(_ message: String) async {
        errorMessage = message
        if case .idle = state {} else if case .rateLimited = state {} else {
            state = .error(message)
        }

        let errorMsg = ChatMessage(
            role: .assistant,
            content: "⚠️ \(message)",
            timestamp: Date(),
            suggestedOutfit: nil
        )
        messages.append(errorMsg)
    }
}

