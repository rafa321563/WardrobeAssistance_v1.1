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

@MainActor
final class AIStyleAssistant: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var errorMessage: String?

    private weak var wardrobeViewModel: WardrobeViewModel?
    private let aiService = AIStyleService.shared
    private let persistenceController = PersistenceController.shared

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
        guard !isProcessing else { return }
        isProcessing = true

        guard let wardrobeViewModel = wardrobeViewModel else {
            await showError("Гардероб недоступен")
            return
        }

        do {
            // Fetch all items from wardrobe
            let items = try await fetchAllItems()

            // Get AI response
            let response = try await aiService.getResponse(
                message: message,
                history: Array(messages.suffix(10)),
                items: items
            )

            // Create assistant message
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response.text,
                timestamp: Date(),
                suggestedOutfit: response.suggestedOutfit
            )

            await MainActor.run {
                self.messages.append(assistantMessage)
                self.isProcessing = false
                self.errorMessage = nil
            }

        } catch let error as AIError {
            await showError(error.errorDescription ?? "Произошла ошибка")
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
        await MainActor.run {
            self.errorMessage = message
            self.isProcessing = false

            let errorMsg = ChatMessage(
                role: .assistant,
                content: "⚠️ \(message)",
                timestamp: Date(),
                suggestedOutfit: nil
            )
            self.messages.append(errorMsg)
        }
    }
}

