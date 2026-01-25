//
//  ErrorHandling.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

// MARK: - Error Alert Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?
    
    func body(content: Content) -> some View {
        content
            .alert("Ошибка", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    func errorAlert(error: Binding<Error?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

// MARK: - Custom Error Types

enum WardrobeError: LocalizedError {
    case saveFailed
    case deleteFailed
    case invalidData
    case networkError
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Не удалось сохранить данные"
        case .deleteFailed:
            return "Не удалось удалить элемент"
        case .invalidData:
            return "Некорректные данные"
        case .networkError:
            return "Проверьте подключение к интернету"
        case .apiKeyMissing:
            return "API ключ не настроен. Свяжитесь с разработчиком."
        }
    }
}

