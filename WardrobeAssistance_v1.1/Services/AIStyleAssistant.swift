//
//  AIStyleAssistant.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import SwiftUI
import Combine

struct AIStyleMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }
    
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date
}

@MainActor
final class AIStyleAssistant: ObservableObject {
    @Published private(set) var messages: [AIStyleMessage] = []
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var errorMessage: String?
    
    private unowned let wardrobeViewModel: WardrobeViewModel
    
    init(wardrobeViewModel: WardrobeViewModel) {
        self.wardrobeViewModel = wardrobeViewModel
        
        messages.append(
            AIStyleMessage(
                role: .assistant,
                text: "Привет! Я твой персональный AI-стилист. Спроси меня о подборе образа, уходе за вещами или как обновить гардероб.",
                timestamp: Date()
            )
        )
    }
    
    func send(message: String) {
        errorMessage = nil
        let userMessage = AIStyleMessage(role: .user, text: message, timestamp: Date())
        messages.append(userMessage)
        
        Task {
            await process(message: message)
        }
    }
    
    private func process(message: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        
        // Simplified response - in a real app, this would call an AI service
        let response = "Спасибо за вопрос! В будущих версиях здесь будет интеграция с AI для персональных советов по стилю."
        
        let assistantMessage = AIStyleMessage(role: .assistant, text: response, timestamp: Date())
        
        await MainActor.run {
            self.messages.append(assistantMessage)
            self.isProcessing = false
        }
    }
}

