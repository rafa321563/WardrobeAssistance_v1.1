//
//  OutfitBuilderView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct OutfitBuilderView: View {
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var storeKitManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingSaveOutfit = false
    @State private var showingOutfitLibrary = false
    @State private var showingMenu = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.name, ascending: true)],
        animation: .default
    )
    private var allItems: FetchedResults<ItemEntity>
    
    var currentOutfitItems: [ItemEntity] {
        outfitViewModel.currentOutfitItems.compactMap { id in
            wardrobeViewModel.getItem(by: id, context: viewContext)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current Outfit Preview
                if !currentOutfitItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(currentOutfitItems) { item in
                                VStack(spacing: 8) {
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
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    Button(action: {
                                        guard let itemId = item.id else { return }
                                        outfitViewModel.removeItemFromCurrentOutfit(itemId)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                    }
                                    .offset(x: 8, y: -8),
                                    alignment: .topTrailing
                                )
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGray6))
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showingSaveOutfit = true
                    }) {
                        Text("Save Outfit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding()
                } else {
                    ModernEmptyStateView(
                        icon: "square.grid.2x2",
                        title: "No items in outfit",
                        message: "Add items from your wardrobe to create an outfit",
                        action: nil,
                        actionLabel: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
                
                Divider()
                
                // Wardrobe Items by Category
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(ClothingCategory.allCases, id: \.self) { category in
                            let categoryItems = allItems.filter { $0.categoryEnum == category }
                            if !categoryItems.isEmpty {
                                CategorySection(
                                    category: category,
                                    items: Array(categoryItems),
                                    onItemTap: { item in
                                        guard let itemId = item.id else { return }
                                        outfitViewModel.addItemToCurrentOutfit(itemId)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Outfit Builder")
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
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        showingOutfitLibrary = true
                    }) {
                        Image(systemName: "square.grid.2x2.fill")
                            .accessibilityLabel("Outfit library")
                            .accessibilityHint("Double tap to view your saved outfits")
                    }
                }
            }
            .sheet(isPresented: $showingSaveOutfit) {
                SaveOutfitView()
                    .environmentObject(outfitViewModel)
            }
            .sheet(isPresented: $showingOutfitLibrary) {
                OutfitLibraryView()
                    .environmentObject(outfitViewModel)
                    .environmentObject(wardrobeViewModel)
            }
            .sheet(isPresented: $showingMenu) {
                SideMenuView()
                    .environmentObject(wardrobeViewModel)
                    .environmentObject(outfitViewModel)
                    .environmentObject(storeKitManager)
            }
            .errorAlert(error: $outfitViewModel.error)
        }
    }
}

struct CategorySection: View {
    let category: ClothingCategory
    let items: [ItemEntity]
    let onItemTap: (ItemEntity) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.blue)
                Text(category.rawValue)
                    .font(.headline)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        Button(action: {
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                            onItemTap(item)
                        }) {
                            ItemThumbnailView(item: item)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                    }
                }
            }
        }
    }
}

struct SaveOutfitView: View {
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var selectedOccasion: Occasion = .casual
    @State private var selectedSeason: Season = .allSeason
    @State private var notes: String = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Outfit Details")) {
                    TextField("Outfit Name", text: $name)
                    
                    Picker("Occasion", selection: $selectedOccasion) {
                        ForEach(Occasion.allCases, id: \.self) { occasion in
                            Text(occasion.rawValue).tag(occasion)
                        }
                    }
                    
                    Picker("Season", selection: $selectedSeason) {
                        ForEach(Season.allCases, id: \.self) { season in
                            Text(season.rawValue).tag(season)
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section(header: Text("Items")) {
                    Text("\(outfitViewModel.currentOutfitItems.count) items")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Save Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        saveOutfit()
                    }
                    .disabled(outfitViewModel.currentOutfitItems.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveOutfit() {
        isSaving = true
        Task {
            await outfitViewModel.saveCurrentOutfit(
                name: name.isEmpty ? "My Outfit" : name,
                occasion: selectedOccasion,
                season: selectedSeason,
                notes: notes.isEmpty ? nil : notes
            )
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

struct OutfitLibraryView: View {
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OutfitEntity.dateCreated, ascending: false)],
        animation: .default
    )
    private var outfits: FetchedResults<OutfitEntity>
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(outfits) { outfit in
                        OutfitCardView(outfit: outfit)
                            .environmentObject(wardrobeViewModel)
                            .environmentObject(outfitViewModel)
                    }
                }
                .padding()
            }
            .navigationTitle("Outfit Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OutfitCardView: View {
    let outfit: OutfitEntity
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var outfitItems: [ItemEntity] {
        outfit.itemsArray.compactMap { id in
            wardrobeViewModel.getItem(by: id, context: viewContext)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Outfit Preview
            Group {
                if let image = outfit.swiftUIImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Show first few items
                    HStack(spacing: 4) {
                        ForEach(Array(outfitItems.prefix(3))) { item in
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
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(outfit.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(outfit.displayOccasion.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Note: rating is optional in Core Data but generated as non-optional Int32
                // Check if rating is set (greater than 0, as valid rating is 1-5)
                if outfit.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(outfit.rating) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
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

#Preview {
    OutfitBuilderView()
        .environmentObject(WardrobeViewModel())
        .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

