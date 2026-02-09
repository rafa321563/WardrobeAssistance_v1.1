//
//  WardrobeView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct WardrobeView: View {
    @EnvironmentObject var viewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var storeKitManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddItem = false
    @State private var showPaywall = false
    @State private var showingMenu = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.dateAdded, ascending: false)],
        animation: .default
    )
    private var allItems: FetchedResults<ItemEntity>

    var filteredItems: [ItemEntity] {
        let predicate = viewModel.buildFilterPredicate()
        if let predicate = predicate {
            return allItems.filter { predicate.evaluate(with: $0) }
        }
        return Array(allItems)
    }

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $viewModel.searchText)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    // Category filter tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ClothingCategory.allCases, id: \.self) { category in
                                CategoryTagView(
                                    category: category,
                                    isSelected: viewModel.selectedCategory == category
                                ) {
                                    if viewModel.selectedCategory == category {
                                        viewModel.selectedCategory = nil
                                    } else {
                                        viewModel.selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 4)

                    // Active non-category filter chips
                    if viewModel.selectedColor != nil ||
                       viewModel.selectedSeason != nil || viewModel.selectedStyle != nil ||
                       viewModel.showFavoritesOnly {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChipView(viewModel: viewModel)
                                Button("Clear All") {
                                    viewModel.clearFilters()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 4)
                    }

                    // Items Grid
                    if filteredItems.isEmpty {
                        ModernEmptyStateView(
                            icon: "tshirt",
                            title: allItems.isEmpty ? "Your Wardrobe is Empty" : "No items found",
                            message: allItems.isEmpty
                                ? "Add your first clothing item to get started"
                                : "Try adjusting your filters",
                            action: allItems.isEmpty ? {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                showingAddItem = true
                            } : nil,
                            actionLabel: allItems.isEmpty ? "Add Item" : nil
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if !storeKitManager.isPremium && allItems.count >= storeKitManager.getFreeTierLimit(.unlimitedItems) {
                        VStack(spacing: 20) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow)
                            Text("Premium Limit Reached")
                                .font(.headline)
                            Text("You've added \(allItems.count) items. Upgrade to Premium for unlimited items.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button(action: {
                                showPaywall = true
                            }) {
                                Text("Upgrade to Premium")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(filteredItems) { item in
                                    ZStack(alignment: .topTrailing) {
                                        NavigationLink(destination: ItemDetailView(item: item)
                                            .environmentObject(viewModel)) {
                                            ItemCardView(item: item)
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        // Heart overlay — outside NavigationLink so it captures taps
                                        Button {
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                            Task {
                                                guard let itemId = item.id else { return }
                                                await viewModel.toggleFavorite(id: itemId)
                                            }
                                        } label: {
                                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                                .foregroundColor(item.isFavorite ? .red : .white)
                                                .padding(8)
                                                .background(Color.black.opacity(0.3))
                                                .clipShape(Circle())
                                        }
                                        .padding(8)
                                    }
                                }
                            }
                            .padding()
                            // Extra bottom padding so FAB doesn't overlap last row
                            .padding(.bottom, 80)
                        }
                    }
                }

                // Floating Add Button
                FloatingAddButton {
                    showingAddItem = true
                }
            }
            .navigationTitle("My Wardrobe")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .accessibilityLabel("Menu")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                            Text("PRO")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppDesign.Colors.premiumGradient)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(storeKitManager)
            }
            .sheet(isPresented: $showingMenu) {
                SideMenuView()
                    .environmentObject(viewModel)
                    .environmentObject(outfitViewModel)
                    .environmentObject(storeKitManager)
            }
            .errorAlert(error: $viewModel.error)
        }
    }
}

// MARK: - Category Tag View

struct CategoryTagView: View {
    let category: ClothingCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppDesign.Colors.primary : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search items...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Filter Chips

struct FilterChipView: View {
    @ObservedObject var viewModel: WardrobeViewModel

    var body: some View {
        Group {
            if let color = viewModel.selectedColor {
                FilterChip(text: color.rawValue, color: .purple) {
                    viewModel.selectedColor = nil
                }
            }

            if let season = viewModel.selectedSeason {
                FilterChip(text: season.rawValue, color: .orange) {
                    viewModel.selectedSeason = nil
                }
            }

            if let style = viewModel.selectedStyle {
                FilterChip(text: style.rawValue, color: .green) {
                    viewModel.selectedStyle = nil
                }
            }

            if viewModel.showFavoritesOnly {
                FilterChip(text: "Favorites", color: .red) {
                    viewModel.showFavoritesOnly = false
                }
            }
        }
    }
}

struct FilterChip: View {
    let text: String
    let color: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(16)
    }
}

// MARK: - Item Card View

struct ItemCardView: View {
    let item: ItemEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            Group {
                if let image = item.swiftUIImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(item.displayColor.color.opacity(0.3))
                        .overlay(
                            Image(systemName: item.displayCategory.icon)
                                .font(.system(size: 40))
                                .foregroundColor(item.displayColor.color)
                        )
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(item.displayCategory.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Circle()
                        .fill(item.displayColor.color)
                        .frame(width: 12, height: 12)
                    Text(item.displayColor.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ItemThumbnailView: View {
    let item: ItemEntity

    var body: some View {
        VStack(spacing: 4) {
            if let image = item.swiftUIImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.displayColor.color.opacity(0.3))
                    .overlay(
                        Image(systemName: item.displayCategory.icon)
                            .foregroundColor(item.displayColor.color)
                    )
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    WardrobeView()
        .environmentObject(WardrobeViewModel())
        .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
        .environmentObject(SubscriptionManager())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
