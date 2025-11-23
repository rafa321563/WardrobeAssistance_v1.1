//
//  OnboardingView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

/// Главный экран онбординга с ярким дизайном и анимациями
struct OnboardingView: View {
    // MARK: - Properties
    
    /// Страницы онбординга
    @State private var pages: [OnboardingPage] = OnboardingDataManager.getPages()
    
    /// Текущая страница
    @State private var currentPage: Int = 0
    
    /// Флаг "Не показывать снова"
    @AppStorage("dontShowOnboardingAgain") private var dontShowAgain: Bool = false
    
    /// Параллакс offset для фона
    @State private var parallaxOffset: CGFloat = 0
    
    /// Показать Paywall
    @State private var showPaywall: Bool = false
    
    /// Замыкание для завершения онбординга
    let onComplete: () -> Void
    
    /// Environment object для Paywall
    @EnvironmentObject var storeKitManager: SubscriptionManager
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Параллакс фон с градиентом
                parallaxBackground
                    .ignoresSafeArea()
                    .offset(y: parallaxOffset)
                
                VStack(spacing: 0) {
                    // Индикатор прогресса
                    modernProgressIndicator
                        .padding(.top, 50)
                        .padding(.horizontal, 20)
                    
                    // TabView с страницами
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                            OnboardingPageView(
                                page: page,
                                isLastPage: index == pages.count - 1,
                                pageIndex: index
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
                    .onChange(of: currentPage) { newValue in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            parallaxOffset = CGFloat(newValue) * -20
                        }
                    }
                    
                    // Кнопки навигации
                    navigationButtons
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(storeKitManager)
            }
        }
    }
    
    // MARK: - Parallax Background
    
    /// Параллакс фон с анимированными градиентами
    private var parallaxBackground: some View {
        ZStack {
            // Базовый градиент текущей страницы
            if currentPage < pages.count {
                let page = pages[currentPage]
                LinearGradient(
                    colors: page.gradient.map { $0.opacity(0.3) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Анимированные круги для глубины
            if currentPage < pages.count {
                let currentGradient = pages[currentPage].gradient
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: currentGradient.map { $0.opacity(0.1) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: CGFloat(200 + index * 100))
                        .offset(
                            x: CGFloat(index * 50 - 100),
                            y: CGFloat(index * 80 - 100) + parallaxOffset * 0.5
                        )
                        .blur(radius: 40)
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Modern Progress Indicator
    
    /// Современный индикатор прогресса
    private var modernProgressIndicator: some View {
        HStack(spacing: 10) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: index == currentPage 
                                ? pages[currentPage].gradient 
                                : [Color.secondary.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: index == currentPage ? 32 : 10,
                        height: 6
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7),
                        value: currentPage
                    )
            }
        }
    }
    
    // MARK: - Navigation Buttons
    
    /// Кнопки навигации и действия
    private var navigationButtons: some View {
        VStack(spacing: 16) {
            if currentPage == pages.count - 1 {
                // Финальный экран с кнопками
                VStack(spacing: 14) {
                    // Кнопка "Начать бесплатно"
                    Button(action: {
                        completeOnboarding()
                    }) {
                        HStack(spacing: 12) {
                            Text(getLocalizedText("Start Free", "Начать бесплатно"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                // Градиентный фон
                                LinearGradient(
                                    colors: OnboardingColors.gradient4,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                // Темный оверлей для улучшения контрастности текста
                                Color.black.opacity(0.1)
                            }
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.primary.opacity(0.2), radius: 15, x: 0, y: 8)
                    }
                    .buttonStyle(NeomorphicButtonStyle())
                    
                    // Кнопка "Получить Премиум"
                    Button(action: {
                        // Show paywall before completing onboarding
                        showPaywall = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text(getLocalizedText("Get Premium", "Получить Премиум"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(OnboardingColors.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            GlassmorphismCard()
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: OnboardingColors.gradient4,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(NeomorphicButtonStyle())
                    
                    // Чекбокс "Не показывать снова"
                    Toggle(isOn: $dontShowAgain) {
                        Text(getLocalizedText("Don't show again", "Не показывать снова"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .toggleStyle(ModernCheckboxStyle())
                }
            } else {
                    // Кнопка "Далее"
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if currentPage < pages.count - 1 {
                            currentPage += 1
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Text(getLocalizedText("Next", "Далее"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        ZStack {
                            // Градиентный фон
                            LinearGradient(
                                colors: pages[currentPage].gradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            // Темный оверлей для улучшения контрастности текста
                            Color.black.opacity(0.1)
                        }
                    )
                    .cornerRadius(20)
                    .shadow(
                        color: Color.primary.opacity(0.2),
                        radius: 15,
                        x: 0,
                        y: 8
                    )
                }
                .buttonStyle(NeomorphicButtonStyle())
            }
        }
    }
    
    // MARK: - Methods
    
    /// Завершение онбординга
    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            onComplete()
        }
    }
    
    /// Локализация текста
    private func getLocalizedText(_ english: String, _ russian: String) -> String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return locale == "ru" ? russian : english
    }
}

// MARK: - Onboarding Page View

/// Отдельный экран онбординга с анимациями
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLastPage: Bool
    let pageIndex: Int
    
    @State private var isAnimating: Bool = false
    @State private var iconFloatOffset: CGFloat = 0
    @State private var featureAnimations: [Bool] = []
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Анимированная иконка
            animatedIconView
                .padding(.bottom, 50)
            
            // Заголовок
            titleView
                .padding(.bottom, 16)
            
            // Подзаголовок
            subtitleView
                .padding(.bottom, 24)
            
            // Акцентный текст
            accentTextView
                .padding(.bottom, 32)
            
            // Список фич (если есть)
            if let features = page.features {
                featuresListView(features: features)
                    .padding(.bottom, 32)
            }
            
            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Animated Icon View
    
    /// Анимированная иконка с float эффектом
    private var animatedIconView: some View {
        ZStack {
            // Свечение вокруг иконки
            Circle()
                .fill(
                    RadialGradient(
                        colors: page.gradient.map { $0.opacity(0.3) },
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 30)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 0.6 : 0.0)
            
            // Glassmorphism круг
            Circle()
                .fill(
                    LinearGradient(
                        colors: page.gradient.map { $0.opacity(0.2) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: page.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: page.gradient.first?.opacity(0.3) ?? Color.clear, radius: 20, x: 0, y: 10)
            
            // Иконка
            Image(systemName: page.icon)
                .font(.system(size: 70, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: page.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(y: iconFloatOffset)
                .scaleEffect(isAnimating ? 1.0 : 0.3)
                .opacity(isAnimating ? 1.0 : 0.0)
        }
    }
    
    // MARK: - Title View
    
    /// Заголовок страницы
    private var titleView: some View {
        Text(getLocalizedTitle())
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(
                LinearGradient(
                    colors: page.gradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(y: isAnimating ? 0 : 30)
            .opacity(isAnimating ? 1.0 : 0.0)
    }
    
    // MARK: - Subtitle View
    
    /// Подзаголовок страницы
    private var subtitleView: some View {
        Text(getLocalizedSubtitle())
            .font(.system(size: 18, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundColor(.primary)
            .lineSpacing(6)
            .offset(y: isAnimating ? 0 : 30)
            .opacity(isAnimating ? 1.0 : 0.0)
    }
    
    // MARK: - Accent Text View
    
    /// Акцентный текст
    private var accentTextView: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: page.gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text(getLocalizedAccentText())
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: page.gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            GlassmorphismCard()
        )
        .offset(y: isAnimating ? 0 : 30)
        .opacity(isAnimating ? 1.0 : 0.0)
    }
    
    // MARK: - Features List View
    
    /// Список фич с анимацией
    private func featuresListView(features: [OnboardingFeature]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                if index < featureAnimations.count && featureAnimations[index] {
                    FeatureRowView(feature: feature, gradient: page.gradient)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            GlassmorphismCard()
        )
    }
    
    // MARK: - Animations
    
    /// Запуск анимаций
    private func startAnimations() {
        isAnimating = false
        iconFloatOffset = 0
        featureAnimations = Array(repeating: false, count: page.features?.count ?? 0)
        
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            isAnimating = true
        }
        
        // Float анимация для иконки
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            iconFloatOffset = -10
        }
        
        // Последовательное появление фич
        if let features = page.features {
            for index in 0..<features.count {
                withAnimation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                    .delay(Double(index) * 0.15)
                ) {
                    if index < featureAnimations.count {
                        featureAnimations[index] = true
                    }
                }
            }
        }
    }
    
    // MARK: - Localization Helpers
    
    private func getLocalizedTitle() -> String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return locale == "ru" ? page.titleLocalized : page.title
    }
    
    private func getLocalizedSubtitle() -> String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return locale == "ru" ? page.subtitleLocalized : page.subtitle
    }
    
    private func getLocalizedAccentText() -> String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return locale == "ru" ? page.accentTextLocalized : page.accentText
    }
}

// MARK: - Feature Row View

/// Строка с функцией
struct FeatureRowView: View {
    let feature: OnboardingFeature
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 16) {
            // Иконка функции
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.2) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Название функции
            Text(getLocalizedTitle())
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func getLocalizedTitle() -> String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return locale == "ru" ? feature.titleLocalized : feature.title
    }
}

// MARK: - Glassmorphism Card

/// Карточка с эффектом glassmorphism
struct GlassmorphismCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
                .shadow(color: Color.primary.opacity(0.15), radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Neomorphic Button Style

/// Неоморфный стиль кнопки
struct NeomorphicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Modern Checkbox Style

/// Современный стиль чекбокса
struct ModernCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                configuration.isOn.toggle()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            configuration.isOn
                                ? LinearGradient(
                                    colors: OnboardingColors.gradient4,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.secondary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 24, height: 24)
                    
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    OnboardingView(onComplete: {})
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    OnboardingView(onComplete: {})
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    OnboardingView(onComplete: {})
        .environmentObject(SubscriptionManager())
        .environment(\.sizeCategory, .accessibilityLarge)
}
