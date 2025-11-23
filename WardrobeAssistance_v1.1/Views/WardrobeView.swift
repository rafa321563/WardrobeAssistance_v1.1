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
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingFilters = false
    @State private var showingAddItem = false
    
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
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Filter Chips
                if viewModel.selectedCategory != nil || viewModel.selectedColor != nil ||
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
                    .padding(.vertical, 8)
                }
                
                // Items Grid
                if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tshirt")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No items found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Add your first clothing item to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(filteredItems) { item in
                                NavigationLink(destination: ItemDetailView(item: item)
                                    .environmentObject(viewModel)) {
                                    ItemCardView(item: item)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Wardrobe")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showingFilters) {
                FilterView()
                    .environmentObject(viewModel)
            }
        }
    }
}

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

struct FilterChipView: View {
    @ObservedObject var viewModel: WardrobeViewModel
    
    var body: some View {
        Group {
            if let category = viewModel.selectedCategory {
                FilterChip(text: category.rawValue, color: .blue) {
                    viewModel.selectedCategory = nil
                }
            }
            
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

struct ItemCardView: View {
    let item: ItemEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            ZStack(alignment: .topTrailing) {
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
                
                if item.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                        .padding(8)
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
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

