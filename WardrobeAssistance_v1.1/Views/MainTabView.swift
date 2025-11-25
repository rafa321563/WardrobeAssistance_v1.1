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
    
    // StoreKit manager from app entry point
    @EnvironmentObject var storeKitManager: SubscriptionManager
    
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
                    Label(Text("tab_home"), systemImage: "house.fill")
                }
            
            WardrobeView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(storeKitManager)
                .tabItem {
                    Label(Text("tab_wardrobe"), systemImage: "tshirt.fill")
                }
            
            OutfitBuilderView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .tabItem {
                    Label(Text("tab_outfits"), systemImage: "square.grid.2x2.fill")
                }
            
            RecommendationsView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .environmentObject(recommendationViewModel)
                .environmentObject(styleAssistant)
                .tabItem {
                    Label(Text("tab_ai_style"), systemImage: "sparkles")
                }
            
            MoreView()
                .environmentObject(storeKitManager)
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .tabItem {
                    Label(Text("tab_more"), systemImage: "ellipsis.circle")
                }
        }
        .accentColor(.blue)
        .onAppear {
            print("MainTabView appeared - creating new ViewModels")
            print("MainTabView - wardrobeViewModel exists: \(wardrobeViewModel != nil)")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SubscriptionManager())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

