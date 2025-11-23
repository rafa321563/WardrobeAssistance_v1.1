//
//  WardrobeAssistance_v1_1App.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

@main
struct WardrobeAssistance_v1_1App: App {
    let persistenceController = PersistenceController.shared
    
    // MARK: - Subscription Manager
    @StateObject private var storeKitManager = SubscriptionManager()
    
    // MARK: - AppStorage для онбординга
    /// Флаг, показывающий, был ли завершен онбординг
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    // Основное приложение
                    MainTabView()
                        .environment(\.managedObjectContext, persistenceController.viewContext)
                        .environmentObject(storeKitManager)
                        .transition(.opacity)
                } else {
                    // Экран онбординга
                    OnboardingView {
                        // Завершение онбординга
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .environmentObject(storeKitManager)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        }
    }
}
