//
//  OnboardingDataModel.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

/// Цветовая палитра для онбординга
struct OnboardingColors {
    static let purple = Color(hex: "8B5CF6")
    static let pink = Color(hex: "EC4899")
    static let blue = Color(hex: "3B82F6")
    
    /// Градиент для экрана 1
    static var gradient1: [Color] {
        [purple, pink]
    }
    
    /// Градиент для экрана 2
    static var gradient2: [Color] {
        [pink, blue]
    }
    
    /// Градиент для экрана 3
    static var gradient3: [Color] {
        [blue, purple]
    }
    
    /// Градиент для экрана 4
    static var gradient4: [Color] {
        [purple, pink, blue]
    }
}

// Color hex extension is now in DesignSystem.swift

/// Модель данных для экрана онбординга
struct OnboardingPage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let titleLocalized: String
    let subtitle: String
    let subtitleLocalized: String
    let icon: String
    let accentText: String
    let accentTextLocalized: String
    let gradient: [Color]
    let features: [OnboardingFeature]?
    
    init(
        title: String,
        titleLocalized: String,
        subtitle: String,
        subtitleLocalized: String,
        icon: String,
        accentText: String,
        accentTextLocalized: String,
        gradient: [Color],
        features: [OnboardingFeature]? = nil
    ) {
        self.title = title
        self.titleLocalized = titleLocalized
        self.subtitle = subtitle
        self.subtitleLocalized = subtitleLocalized
        self.icon = icon
        self.accentText = accentText
        self.accentTextLocalized = accentTextLocalized
        self.gradient = gradient
        self.features = features
    }
}

/// Модель функции приложения
struct OnboardingFeature: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let titleLocalized: String
}

/// Менеджер данных онбординга
class OnboardingDataManager {
    /// Получить все страницы онбординга
    static func getPages() -> [OnboardingPage] {
        return [
            // Экран 1 - Умный гардероб
            OnboardingPage(
                title: "Your Digital Wardrobe",
                titleLocalized: "Ваш цифровой гардероб",
                subtitle: "Add items in seconds - just take a photo",
                subtitleLocalized: "Добавляйте вещи за секунды - просто сфотографируйте",
                icon: "camera.fill",
                accentText: "Automatic detection of categories and colors",
                accentTextLocalized: "Автоматическое определение категорий и цветов",
                gradient: OnboardingColors.gradient1,
                features: [
                    OnboardingFeature(icon: "photo.fill", title: "Photo Items", titleLocalized: "Фото вещей"),
                    OnboardingFeature(icon: "tag.fill", title: "Auto Categories", titleLocalized: "Автокатегории"),
                    OnboardingFeature(icon: "paintpalette.fill", title: "Color Detection", titleLocalized: "Определение цветов")
                ]
            ),
            
            // Экран 2 - AI-стилист
            OnboardingPage(
                title: "Personal AI Stylist",
                titleLocalized: "Персональный AI-стилист",
                subtitle: "Smart outfit recommendations based on your style",
                subtitleLocalized: "Умные рекомендации образов на основе вашего стиля",
                icon: "sparkles",
                accentText: "Considers weather, occasion and your preferences",
                accentTextLocalized: "Учитывает погоду, повод и ваши предпочтения",
                gradient: OnboardingColors.gradient2,
                features: [
                    OnboardingFeature(icon: "brain.head.profile", title: "AI Recommendations", titleLocalized: "AI-рекомендации"),
                    OnboardingFeature(icon: "cloud.sun.fill", title: "Weather Adaptation", titleLocalized: "Погодная адаптация"),
                    OnboardingFeature(icon: "heart.fill", title: "Style Preferences", titleLocalized: "Предпочтения стиля")
                ]
            ),
            
            // Экран 3 - Организация
            OnboardingPage(
                title: "Everything Under Control",
                titleLocalized: "Все под контролем",
                subtitle: "Create collections, save outfits, track your style",
                subtitleLocalized: "Создавайте коллекции, сохраняйте образы, отслеживайте стиль",
                icon: "chart.bar.fill",
                accentText: "Analytics of your style and trends",
                accentTextLocalized: "Аналитика вашего стиля и трендов",
                gradient: OnboardingColors.gradient3,
                features: [
                    OnboardingFeature(icon: "square.grid.2x2.fill", title: "Collections", titleLocalized: "Коллекции"),
                    OnboardingFeature(icon: "chart.line.uptrend.xyaxis", title: "Style Analytics", titleLocalized: "Аналитика стиля"),
                    OnboardingFeature(icon: "icloud.fill", title: "Cloud Sync", titleLocalized: "Облачная синхронизация")
                ]
            ),
            
            // Экран 4 - Начало работы
            OnboardingPage(
                title: "Ready to Look Perfect?",
                titleLocalized: "Готовы выглядеть идеально?",
                subtitle: "Start creating your unique style right now",
                subtitleLocalized: "Начните создавать свой уникальный стиль прямо сейчас",
                icon: "star.fill",
                accentText: "Join thousands of stylish users",
                accentTextLocalized: "Присоединяйтесь к тысячам стильных пользователей",
                gradient: OnboardingColors.gradient4,
                features: nil
            )
        ]
    }
}

