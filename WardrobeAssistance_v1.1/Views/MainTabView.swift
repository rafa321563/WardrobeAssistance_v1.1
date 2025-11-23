//
//  MainTabView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

struct MainTabView: View {
    // MainTabView owns all ViewModels via @StateObject, ensuring proper lifecycle management
    // Child ViewModels hold references to parent ViewModels:
    // - OutfitViewModel and RecommendationViewModel: strong references (safe - same lifetime)
    // - AIStyleAssistant: weak reference to WardrobeViewModel (prevents retain cycles)
    @StateObject private var wardrobeViewModel = WardrobeViewModel()
    @StateObject private var outfitViewModel: OutfitViewModel
    @StateObject private var recommendationViewModel: RecommendationViewModel
    @StateObject private var styleAssistant: AIStyleAssistant
    
    init() {
        // Create ViewModels with proper dependency injection
        // All ViewModels are owned by MainTabView, so strong references between them are safe
        let wardrobeVM = WardrobeViewModel()
        let outfitVM = OutfitViewModel(wardrobeViewModel: wardrobeVM)
        let recommendationVM = RecommendationViewModel(wardrobeViewModel: wardrobeVM, outfitViewModel: outfitVM)
        // AIStyleAssistant uses weak reference to prevent retain cycles
        let styleAssistant = AIStyleAssistant(wardrobeViewModel: wardrobeVM)
        
        _wardrobeViewModel = StateObject(wrappedValue: wardrobeVM)
        _outfitViewModel = StateObject(wrappedValue: outfitVM)
        _recommendationViewModel = StateObject(wrappedValue: recommendationVM)
        _styleAssistant = StateObject(wrappedValue: styleAssistant)
    }
    
    var body: some View {
        TabView {
            HomeView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .environmentObject(recommendationViewModel)
                .environmentObject(styleAssistant)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            WardrobeView()
                .environmentObject(wardrobeViewModel)
                .tabItem {
                    Label("Wardrobe", systemImage: "tshirt.fill")
                }
            
            OutfitBuilderView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .tabItem {
                    Label("Outfits", systemImage: "square.grid.2x2.fill")
                }
            
            RecommendationsView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .environmentObject(recommendationViewModel)
                .environmentObject(styleAssistant)
                .tabItem {
                    Label("AI Style", systemImage: "sparkles")
                }
            
            AnalyticsView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }
            
            CalendarView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

