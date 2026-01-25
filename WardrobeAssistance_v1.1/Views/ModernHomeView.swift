//
//  ModernHomeView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct ModernHomeView: View {
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingAddItem = false
    
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
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppDesign.Spacing.l) {
                        // Daily Recommendation
                        ModernDailyRecommendationCard()
                            .environmentObject(recommendationViewModel)
                            .environmentObject(wardrobeViewModel)
                            .environmentObject(outfitViewModel)
                            .padding(.horizontal, AppDesign.Spacing.m)
                            .padding(.top, AppDesign.Spacing.m)
                        
                        // Quick Stats
                        ModernQuickStatsView(itemCount: allItems.count, outfitCount: allOutfits.count)
                            .padding(.horizontal, AppDesign.Spacing.m)
                        
                        // Recent Items
                        if !allItems.isEmpty {
                            ModernRecentItemsSection(items: Array(allItems.prefix(6)))
                                .padding(.horizontal, AppDesign.Spacing.m)
                        } else {
                            ModernEmptyStateView(
                                icon: "tshirt",
                                title: "Your Wardrobe is Empty",
                                message: "Add your first clothing item to get started",
                                action: {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    showingAddItem = true
                                },
                                actionLabel: "Add Item"
                            )
                            .padding(.horizontal, AppDesign.Spacing.m)
                        }
                        
                        // Favorite Outfits
                        let favoriteOutfits = Array(allOutfits.filter { $0.isFavorite }.prefix(3))
                        if !favoriteOutfits.isEmpty {
                            ModernFavoriteOutfitsSection(outfits: favoriteOutfits)
                                .environmentObject(wardrobeViewModel)
                                .padding(.horizontal, AppDesign.Spacing.m)
                        }
                    }
                    .padding(.bottom, AppDesign.Spacing.xl)
                }
            }
            .navigationTitle("My Wardrobe")
            .toolbar {
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
        }
    }
}

// MARK: - Modern Daily Recommendation Card

struct ModernDailyRecommendationCard: View {
    @EnvironmentObject var recommendationViewModel: RecommendationViewModel
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.m) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow.opacity(0.3), .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Outfit")
                        .font(AppDesign.Typography.headline)
                    
                    if let weather = recommendationViewModel.weatherData {
                        HStack(spacing: 4) {
                            Image(systemName: weather.condition == .sunny ? "sun.max.fill" : "cloud.fill")
                            Text("\(Int(weather.temperature))°C")
                                .font(AppDesign.Typography.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if recommendationViewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                }
                .padding(.vertical, AppDesign.Spacing.xl)
            } else if let recommendation = recommendationViewModel.dailyRecommendation,
                      !recommendation.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppDesign.Spacing.m) {
                        ForEach(recommendation, id: \.self) { itemId in
                            if let item = wardrobeViewModel.getItem(by: itemId, context: viewContext) {
                                ModernItemThumbnail(item: item)
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
                    HStack {
                        Text("Use This Outfit")
                            .font(AppDesign.Typography.bodyBold)
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PremiumButtonStyle())
            } else {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    recommendationViewModel.generateDailyRecommendation()
                }) {
                    HStack {
                        Text("Generate Outfit")
                            .font(AppDesign.Typography.bodyBold)
                        Image(systemName: "sparkles")
                    }
                }
                .buttonStyle(PremiumButtonStyle())
            }
        }
        .cardStyle()
    }
}

// MARK: - Modern Quick Stats

struct ModernQuickStatsView: View {
    let itemCount: Int
    let outfitCount: Int
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.dateAdded, ascending: false)],
        predicate: NSPredicate(format: "isFavorite == YES"),
        animation: .default
    )
    private var favoriteItems: FetchedResults<ItemEntity>
    
    var body: some View {
        HStack(spacing: AppDesign.Spacing.m) {
            ModernStatCard(
                title: "Items",
                value: "\(itemCount)",
                icon: "tshirt.fill",
                gradient: [.blue, .cyan]
            )
            
            ModernStatCard(
                title: "Outfits",
                value: "\(outfitCount)",
                icon: "square.grid.2x2.fill",
                gradient: [.purple, .pink]
            )
            
            ModernStatCard(
                title: "Favorites",
                value: "\(favoriteItems.count)",
                icon: "heart.fill",
                gradient: [.red, .pink]
            )
        }
    }
}

struct ModernStatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.s) {
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
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(value)
                .font(AppDesign.Typography.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(AppDesign.Typography.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesign.Spacing.m)
        .cardStyle()
    }
}

// MARK: - Modern Recent Items Section

struct ModernRecentItemsSection: View {
    let items: [ItemEntity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.m) {
            HStack {
                Text("Recent Items")
                    .font(AppDesign.Typography.headline)
                Spacer()
                NavigationLink("See All") {
                    WardrobeView()
                }
                .font(AppDesign.Typography.caption)
                .foregroundColor(.blue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppDesign.Spacing.m) {
                    ForEach(items.reversed()) { item in
                        ModernItemThumbnail(item: item)
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct ModernItemThumbnail: View {
    let item: ItemEntity
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.s) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if item.imageFileName != nil && !item.imageFileName!.isEmpty {
                        CachedImageView(item: item)
                    } else {
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.medium)
                            .fill(item.displayColor.color.opacity(0.3))
                            .overlay(
                                Image(systemName: item.displayCategory.icon)
                                    .font(.title2)
                                    .foregroundColor(item.displayColor.color)
                            )
                    }
                }
                
                if item.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(6)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .padding(6)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.medium))
            
            Text(item.displayName)
                .font(AppDesign.Typography.caption)
                .lineLimit(1)
                .frame(width: 100)
        }
    }
}

// MARK: - Modern Favorite Outfits Section

struct ModernFavoriteOutfitsSection: View {
    let outfits: [OutfitEntity]
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.m) {
            Text("Favorite Outfits")
                .font(AppDesign.Typography.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppDesign.Spacing.m) {
                    ForEach(outfits) { outfit in
                        ModernOutfitThumbnail(outfit: outfit)
                            .environmentObject(wardrobeViewModel)
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct ModernOutfitThumbnail: View {
    let outfit: OutfitEntity
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var outfitItems: [ItemEntity] {
        outfit.itemsArray.compactMap { id in
            wardrobeViewModel.getItem(by: id, context: viewContext)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.s) {
            ZStack {
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
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.medium))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(outfit.displayName)
                    .font(AppDesign.Typography.captionBold)
                    .lineLimit(1)
                
                Text(outfit.displayOccasion.rawValue)
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, alignment: .leading)
        }
    }
}

// MARK: - Modern Empty State

struct ModernEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.l) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(AppDesign.Colors.primaryGradient)
            
            VStack(spacing: AppDesign.Spacing.s) {
                Text(title)
                    .font(AppDesign.Typography.headline)
                
                Text(message)
                    .font(AppDesign.Typography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppDesign.Spacing.xl)
            }
            
            if let action = action, let actionLabel = actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(AppDesign.Typography.bodyBold)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, AppDesign.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.xxxl)
        .cardStyle()
    }
}

#Preview {
    ModernHomeView()
        .environmentObject(WardrobeViewModel())
        .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
        .environmentObject(RecommendationViewModel(wardrobeViewModel: WardrobeViewModel(), outfitViewModel: OutfitViewModel(wardrobeViewModel: WardrobeViewModel())))
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

