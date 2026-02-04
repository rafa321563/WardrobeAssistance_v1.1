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
            //    ToolbarItem(placement: .navigationBarLeading) {
                    // Пустой элемент для симметричного выравнивания
              //      Color.clear
               //         .frame(width: 32, height: 32)
                //}
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showingAddItem = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .accessibilityLabel("Add new item")
                            .accessibilityHint("Double tap to add a new clothing item")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
                    .environmentObject(wardrobeViewModel)
            }
            .errorAlert(error: $wardrobeViewModel.error)
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
                Text("Образ на сегодня")
                    .font(.headline)
                Spacer()
                if let weather = recommendationViewModel.weatherData {
                    HStack(spacing: 4) {
                        Image(systemName: weatherIcon(for: weather.condition))
                            .foregroundColor(weatherColor(for: weather.condition))
                        Text("\(Int(weather.temperature))°C")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }

            // AI Reasoning
            if let reasoning = recommendationViewModel.aiReasoning {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text(reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
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
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    if let recommendation = recommendationViewModel.dailyRecommendation {
                        outfitViewModel.currentOutfitItems = recommendation
                    }
                }) {
                    Text("Использовать этот образ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            } else {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    recommendationViewModel.generateDailyRecommendation()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Подобрать образ")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }

            // Error message
            if let errorMessage = recommendationViewModel.aiErrorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    private func weatherIcon(for condition: WeatherCondition) -> String {
        switch condition {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .snowy: return "snow"
        case .windy: return "wind"
        case .foggy: return "cloud.fog.fill"
        }
    }

    private func weatherColor(for condition: WeatherCondition) -> Color {
        switch condition {
        case .sunny: return .orange
        case .cloudy: return .gray
        case .rainy: return .blue
        case .snowy: return .cyan
        case .windy: return .teal
        case .foggy: return .gray
        }
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
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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

