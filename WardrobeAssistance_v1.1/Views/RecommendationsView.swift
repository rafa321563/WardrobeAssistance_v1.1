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
    @EnvironmentObject var storeKitManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingMenu = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Style Preference Picker
                    StylePreferencePicker()
                        .environmentObject(recommendationViewModel)

                    // Weather Card with Refresh
                    if let weather = recommendationViewModel.weatherData {
                        WeatherCard(weather: weather)
                            .environmentObject(recommendationViewModel)
                    }

                    // Daily Recommendation
                    DailyRecommendationSection()
                        .environmentObject(recommendationViewModel)
                        .environmentObject(wardrobeViewModel)
                        .environmentObject(outfitViewModel)

                    // Occasion Quick Actions
                    OccasionQuickActions()
                        .environmentObject(recommendationViewModel)

                    // AI Chat Access
                    NavigationLink(destination: AIStylistChatView()
                        .environmentObject(styleAssistant)
                        .environmentObject(wardrobeViewModel)) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Чат с AI стилистом")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Рекомендации")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .accessibilityLabel("Menu")
                    }
                }
            }
            .sheet(isPresented: $showingMenu) {
                SideMenuView()
                    .environmentObject(wardrobeViewModel)
                    .environmentObject(outfitViewModel)
                    .environmentObject(storeKitManager)
            }
        }
    }
}

struct StylePreferencePicker: View {
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Предпочитаемый стиль")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StylePreference.allCases, id: \.self) { preference in
                        Button(action: {
                            recommendationViewModel.stylePreference = preference
                        }) {
                            Text(preference.localizedName)
                                .font(.subheadline)
                                .fontWeight(recommendationViewModel.stylePreference == preference ? .semibold : .regular)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    recommendationViewModel.stylePreference == preference ?
                                    Color.blue : Color(.systemGray6)
                                )
                                .foregroundColor(
                                    recommendationViewModel.stylePreference == preference ?
                                    .white : .primary
                                )
                                .cornerRadius(16)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct OccasionQuickActions: View {
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подобрать образ")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                OccasionButton(icon: "💼", title: "Работа", occasion: .work)
                OccasionButton(icon: "❤️", title: "Свидание", occasion: .date)
                OccasionButton(icon: "🎉", title: "Вечеринка", occasion: .party)
                OccasionButton(icon: "🏃", title: "Спорт", occasion: .sports)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct OccasionButton: View {
    let icon: String
    let title: String
    let occasion: Occasion

    @EnvironmentObject var recommendationViewModel: RecommendationViewModel

    var body: some View {
        Button(action: {
            recommendationViewModel.generateOutfitForOccasion(occasion)
        }) {
            VStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 32))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WeatherCard: View {
    let weather: WeatherData

    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: weatherIcon(for: weather.condition))
                            .font(.title)
                        Text(weatherName(for: weather.condition))
                            .font(.headline)
                    }

                    Text("\(Int(weather.temperature))°C")
                        .font(.system(size: 48, weight: .bold))

                    HStack(spacing: 12) {
                        WeatherDetail(icon: "drop.fill", value: "\(Int(weather.humidity))%")
                        WeatherDetail(icon: "wind", value: "\(Int(weather.windSpeed)) м/с")
                    }
                }

                Spacer()
            }

            Button(action: {
                isRefreshing = true
                Task {
                    await recommendationViewModel.refreshWeather()
                    isRefreshing = false
                }
            }) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Обновить погоду")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
            }
            .disabled(isRefreshing)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundColor(.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    private func weatherName(for condition: WeatherCondition) -> String {
        switch condition {
        case .sunny: return "Солнечно"
        case .cloudy: return "Облачно"
        case .rainy: return "Дождь"
        case .snowy: return "Снег"
        case .windy: return "Ветрено"
        case .foggy: return "Туман"
        }
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
}

struct WeatherDetail: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
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
            Text("Рекомендация дня")
                .font(.headline)

            if recommendationViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let items = recommendationViewModel.dailyRecommendation, !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items, id: \.self) { itemID in
                            if let item = wardrobeViewModel.getItem(by: itemID, context: viewContext) {
                                ItemThumbnail(item: item)
                            }
                        }
                    }
                }

                if let reasoning = recommendationViewModel.aiReasoning {
                    Text(reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                Button(action: {
                    if let items = recommendationViewModel.dailyRecommendation {
                        outfitViewModel.currentOutfitItems = items
                    }
                }) {
                    Text("Использовать этот образ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            } else {
                Button(action: {
                    recommendationViewModel.generateDailyRecommendation()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Подобрать образ")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }

            if let error = recommendationViewModel.aiErrorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
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
}

struct ItemThumbnail: View {
    let item: ItemEntity

    var body: some View {
        VStack(spacing: 4) {
            if let fileName = item.imageFileName,
               let image = ImageFileManager.shared.loadImage(filename: fileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
            }

            if let name = item.name {
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .frame(width: 80)
    }
}

#Preview {
    NavigationView {
        RecommendationsView()
            .environmentObject(WardrobeViewModel())
            .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
            .environmentObject(RecommendationViewModel(wardrobeViewModel: WardrobeViewModel(), outfitViewModel: OutfitViewModel(wardrobeViewModel: WardrobeViewModel())))
            .environmentObject(AIStyleAssistant(wardrobeViewModel: WardrobeViewModel()))
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
