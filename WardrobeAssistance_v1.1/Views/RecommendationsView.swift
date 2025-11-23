//
//  RecommendationsView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct RecommendationsView: View {
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    @EnvironmentObject var styleAssistant: AIStyleAssistant
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedItem: ItemEntity?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.name, ascending: true)],
        animation: .default
    )
    private var allItems: FetchedResults<ItemEntity>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Weather Card
                    if let weather = recommendationViewModel.weatherData {
                        WeatherCard(weather: weather)
                    }
                    
                    // Daily Recommendation
                    DailyRecommendationSection()
                        .environmentObject(recommendationViewModel)
                        .environmentObject(wardrobeViewModel)
                        .environmentObject(outfitViewModel)
                    
                    AIInsightsSection()
                        .environmentObject(recommendationViewModel)
                    
                    NavigationLink(destination: AIStylistChatView().environmentObject(styleAssistant)) {
                        HStack {
                            Image(systemName: "person.text.rectangle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Stylist Chat")
                                    .font(.headline)
                                Text("Получай советы и задавай вопросы персональному стилисту.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.primary.opacity(0.12), radius: 6, x: 0, y: 2)
                    }
                    
                    // Smart Matching
                    if let selectedItem = selectedItem {
                        SmartMatchingSection(item: selectedItem)
                            .environmentObject(recommendationViewModel)
                            .environmentObject(wardrobeViewModel)
                    } else {
                        // Select an item to see matches
                        VStack(spacing: 16) {
                            Text("Select an item to see smart matches")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(allItems.prefix(10))) { item in
                                        Button(action: {
                                            selectedItem = item
                                        }) {
                                            ItemThumbnailView(item: item)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(selectedItem?.id == item.id ? Color.blue : Color.clear, lineWidth: 2)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    
                    // Occasion-based Recommendations
                    OccasionRecommendationsSection()
                        .environmentObject(outfitViewModel)
                        .environmentObject(wardrobeViewModel)
                }
                .padding()
            }
            .navigationTitle("AI Style Assistant")
        }
    }
}

struct WeatherCard: View {
    let weather: WeatherData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: weatherIcon)
                    .font(.title)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Weather")
                        .font(.headline)
                    Text("\(Int(weather.temperature))°C • \(weather.condition.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            HStack {
                WeatherInfo(label: "Humidity", value: "\(Int(weather.humidity))%")
                Spacer()
                WeatherInfo(label: "Wind", value: "\(Int(weather.windSpeed)) km/h")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.15), radius: 8, x: 0, y: 2)
    }
    
    var weatherIcon: String {
        switch weather.condition {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .snowy: return "cloud.snow.fill"
        case .windy: return "wind"
        case .foggy: return "cloud.fog.fill"
        }
    }
}

struct WeatherInfo: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct DailyRecommendationSection: View {
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Daily Outfit Recommendation")
                    .font(.headline)
                Spacer()
                Button(action: {
                    recommendationViewModel.generateDailyRecommendation()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
            
            if recommendationViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let recommendation = recommendationViewModel.dailyRecommendation,
                      !recommendation.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(recommendation, id: \.self) { itemId in
                            if let item = wardrobeViewModel.getItem(by: itemId, context: viewContext) {
                                VStack(spacing: 8) {
                                    ItemThumbnailView(item: item)
                                    Text(item.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .frame(width: 100)
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
                
                if let reasoning = recommendationViewModel.aiReasoning {
                    Text("AI Insight: \(reasoning)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            } else {
                Button(action: {
                    recommendationViewModel.generateDailyRecommendation()
                }) {
                    Text("Generate Recommendation")
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

struct SmartMatchingSection: View {
    let item: ItemEntity
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var matches: [ItemEntity] {
        recommendationViewModel.getSmartMatchingItems(for: item, context: viewContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                Text("Smart Matches for \(item.displayName)")
                    .font(.headline)
                Spacer()
            }
            
            if matches.isEmpty {
                Text("No matches found. Try adding more items to your wardrobe.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(matches.prefix(10)) { match in
                            VStack(spacing: 8) {
                                ItemThumbnailView(item: match)
                                Text(match.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(width: 100)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.15), radius: 8, x: 0, y: 2)
    }
}

struct OccasionRecommendationsSection: View {
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Occasion-Based Outfits")
                .font(.headline)
            
            ForEach(Occasion.allCases.prefix(4), id: \.self) { occasion in
                let outfits = outfitViewModel.getOutfitsForOccasion(occasion, context: viewContext)
                if !outfits.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(occasion.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(outfits.prefix(5)) { outfit in
                                    OutfitThumbnailView(outfit: outfit)
                                        .environmentObject(wardrobeViewModel)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
}

private struct AIInsightsSection: View {
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Analysis Status")
                .font(.headline)
            
            if recommendationViewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Запрашиваем свежие рекомендации у AI...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let error = recommendationViewModel.aiErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.subheadline)
                Text("Сеть или ключ API недоступны. Используем локальные рекомендации.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if recommendationViewModel.aiReasoning != nil {
                Label("AI подобрал лук с учётом погоды и стиля.", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            } else {
                Text("AI готов помочь. Сгенерируй образ, чтобы увидеть предложения.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.12), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    RecommendationsView()
        .environmentObject(WardrobeViewModel())
        .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
        .environmentObject(RecommendationViewModel(wardrobeViewModel: WardrobeViewModel(), outfitViewModel: OutfitViewModel(wardrobeViewModel: WardrobeViewModel())))
        .environmentObject(AIStyleAssistant(wardrobeViewModel: WardrobeViewModel()))
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

