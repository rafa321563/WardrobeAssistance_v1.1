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

    // Tab selection with re-tap detection
    enum Tab: Hashable {
        case home, wardrobe, outfits, aiStyle, calendar
    }
    @State private var selectedTab: Tab = .home

    // Navigation reset IDs — changing these recreates NavigationView, popping to root
    @State private var homeNavID = UUID()
    @State private var wardrobeNavID = UUID()
    @State private var outfitsNavID = UUID()
    @State private var aiStyleNavID = UUID()
    @State private var calendarNavID = UUID()

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

    /// Custom binding that detects re-taps on the same tab
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    // Same tab re-tapped — pop to root by recreating NavigationView
                    switch newTab {
                    case .home: homeNavID = UUID()
                    case .wardrobe: wardrobeNavID = UUID()
                    case .outfits: outfitsNavID = UUID()
                    case .aiStyle: aiStyleNavID = UUID()
                    case .calendar: calendarNavID = UUID()
                    }
                }
                selectedTab = newTab
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .environmentObject(recommendationViewModel)
                .environmentObject(styleAssistant)
                .environmentObject(storeKitManager)
                .id(homeNavID)
                .tag(Tab.home)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            WardrobeView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .environmentObject(storeKitManager)
                .id(wardrobeNavID)
                .tag(Tab.wardrobe)
                .tabItem {
                    Label("Wardrobe", systemImage: "tshirt.fill")
                }

            OutfitBuilderView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .environmentObject(storeKitManager)
                .id(outfitsNavID)
                .tag(Tab.outfits)
                .tabItem {
                    Label("Outfits", systemImage: "square.grid.2x2.fill")
                }

            RecommendationsView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .environmentObject(recommendationViewModel)
                .environmentObject(styleAssistant)
                .environmentObject(storeKitManager)
                .id(aiStyleNavID)
                .tag(Tab.aiStyle)
                .tabItem {
                    Label("AI Style", systemImage: "sparkles")
                }

            CalendarView()
                .environmentObject(wardrobeViewModel)
                .environmentObject(outfitViewModel)
                .environmentObject(storeKitManager)
                .id(calendarNavID)
                .tag(Tab.calendar)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
        }
        .accentColor(.blue)
        .onAppear {
            print("MainTabView appeared - creating new ViewModels")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SubscriptionManager())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
