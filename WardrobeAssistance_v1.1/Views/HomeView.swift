//
//  HomeView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingAddItem = false
    @State private var refreshID = UUID()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.dateAdded, ascending: false)],
        animation: .default
    )
    private var allItems: FetchedResults<ItemEntity>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OutfitEntity.dateCreated, ascending: false)],
        animation: .default
    )
    private var allOutfits: FetchedResults<OutfitEntity>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Daily Recommendation Card
                    DailyRecommendationCard()
                        .environmentObject(recommendationViewModel)
                        .environmentObject(wardrobeViewModel)
                        .environmentObject(outfitViewModel)
                    
                    // Quick Stats
                    QuickStatsView(itemCount: allItems.count, outfitCount: allOutfits.count)
                    
                    // Recent Items
                    RecentItemsView(items: Array(allItems.prefix(5)))
                    
                    // Favorite Outfits
                    FavoriteOutfitsView(outfits: Array(allOutfits.filter { $0.isFavorite }.prefix(3)))
                        .environmentObject(wardrobeViewModel)
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .id(refreshID)
            .navigationTitle("My Wardrobe")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Пустой элемент для симметричного выравнивания
                    Color.clear
                        .frame(width: 32, height: 32)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        print("HomeView - Add button tapped")
                        showingAddItem = true 
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
                    .environmentObject(wardrobeViewModel)
            }
            .onAppear {
                print("HomeView appeared - refreshID: \(refreshID)")
                print("HomeView - wardrobeViewModel exists: \(wardrobeViewModel != nil)")
                print("HomeView - items count: \(allItems.count)")
                
                // Принудительное обновление через небольшой delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    refreshID = UUID()
                    print("HomeView - refreshID updated: \(refreshID)")
                }
            }
            .task {
                // Дополнительное принудительное обновление через task
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
                await MainActor.run {
                    refreshID = UUID()
                    print("HomeView - task refreshID updated: \(refreshID)")
                }
            }
        }
    }
}

struct DailyRecommendationCard: View {
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Today's Outfit")
                    .font(.headline)
                Spacer()
                if let weather = recommendationViewModel.weatherData {
                    HStack(spacing: 4) {
                        Image(systemName: weather.condition == .sunny ? "sun.max.fill" : "cloud.fill")
                        Text("\(Int(weather.temperature))°C")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            if recommendationViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let recommendation = recommendationViewModel.dailyRecommendation,
                      !recommendation.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendation, id: \.self) { itemId in
                            if let item = wardrobeViewModel.getItem(by: itemId, context: viewContext) {
                                ItemThumbnailView(item: item)
                            }
                        }
                    }
                }
                
                Button(action: {
                    if let recommendation = recommendationViewModel.dailyRecommendation {
                        outfitViewModel.currentOutfitItems = recommendation
                    }
                }) {
                    Text("Use This Outfit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            ZStack {
                                Color.blue
                                Color.black.opacity(0.1)
                            }
                        )
                        .cornerRadius(12)
                }
            } else {
                Button(action: {
                    recommendationViewModel.generateDailyRecommendation()
                }) {
                    Text("Generate Outfit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            ZStack {
                                Color.blue
                                Color.black.opacity(0.1)
                            }
                        )
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.15), radius: 8, x: 0, y: 2)
    }
}

struct QuickStatsView: View {
    let itemCount: Int
    let outfitCount: Int
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.dateAdded, ascending: false)],
        predicate: NSPredicate(format: "isFavorite == YES"),
        animation: .default
    )
    private var favoriteItems: FetchedResults<ItemEntity>
    
    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Items",
                value: "\(itemCount)",
                icon: "tshirt.fill",
                color: .blue
            )
            
            StatCard(
                title: "Outfits",
                value: "\(outfitCount)",
                icon: "square.grid.2x2.fill",
                color: .purple
            )
            
            StatCard(
                title: "Favorites",
                value: "\(favoriteItems.count)",
                icon: "heart.fill",
                color: .red
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.primary.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

struct RecentItemsView: View {
    let items: [ItemEntity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Items")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items.reversed()) { item in
                        ItemThumbnailView(item: item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FavoriteOutfitsView: View {
    let outfits: [OutfitEntity]
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        if !outfits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Favorite Outfits")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(outfits) { outfit in
                            OutfitThumbnailView(outfit: outfit)
                                .environmentObject(wardrobeViewModel)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct OutfitThumbnailView: View {
    let outfit: OutfitEntity
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var outfitItems: [ItemEntity] {
        outfit.itemsArray.compactMap { id in
            wardrobeViewModel.getItem(by: id, context: viewContext)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if let image = outfit.swiftUIImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(outfitItems.prefix(2))) { item in
                        if let itemImage = item.swiftUIImage {
                            itemImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(item.displayColor.color.opacity(0.3))
                        }
                    }
                }
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HomeView()
        .environmentObject(WardrobeViewModel())
        .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
        .environmentObject(RecommendationViewModel(wardrobeViewModel: WardrobeViewModel(), outfitViewModel: OutfitViewModel(wardrobeViewModel: WardrobeViewModel())))
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

