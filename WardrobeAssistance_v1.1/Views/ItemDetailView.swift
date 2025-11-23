//
//  ItemDetailView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct ItemDetailView: View {
    let item: ItemEntity
    @EnvironmentObject var viewModel: WardrobeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image
                if let image = item.swiftUIImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                } else {
                    Rectangle()
                        .fill(item.displayColor.color.opacity(0.3))
                        .frame(height: 400)
                        .overlay(
                            Image(systemName: item.displayCategory.icon)
                                .font(.system(size: 80))
                                .foregroundColor(item.displayColor.color)
                        )
                }
                
                // Info
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                            Text(item.displayCategory.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            Task {
                                guard let itemId = item.id else { return }
                                await viewModel.toggleFavorite(id: itemId)
                            }
                        }) {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(item.isFavorite ? .red : .gray)
                        }
                    }
                    
                    Divider()
                    
                    // Details
                    DetailRow(label: "Color", value: item.displayColor.rawValue, color: item.displayColor.color)
                    DetailRow(label: "Season", value: item.displaySeason.rawValue)
                    DetailRow(label: "Style", value: item.displayStyle.rawValue)
                    
                    if let material = item.material {
                        DetailRow(label: "Material", value: material)
                    }
                    
                    if let brand = item.brand {
                        DetailRow(label: "Brand", value: brand)
                    }
                    
                    if !item.tagsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(item.tagsArray, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Statistics")
                            .font(.headline)
                        HStack {
                            StatItem(label: "Worn", value: "\(item.wearCount) times")
                            Spacer()
                            if let dateAdded = item.dateAdded {
                                StatItem(label: "Added", value: dateAdded.formatted(date: .abbreviated, time: .omitted))
                            } else {
                                StatItem(label: "Added", value: "Unknown")
                            }
                        }
                        if let lastWorn = item.lastWorn {
                            StatItem(label: "Last Worn", value: lastWorn.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        Task {
                            guard let itemId = item.id else { return }
                            await viewModel.markAsWorn(id: itemId)
                        }
                    }) {
                        Label("Mark as Worn", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: {
                        showingEdit = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditItemView(item: item)
                .environmentObject(viewModel)
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    guard let itemId = item.id else { return }
                    await viewModel.deleteItem(id: itemId)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var color: Color? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if let color = color {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            } else {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
}

struct StatItem: View {
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

struct EditItemView: View {
    let item: ItemEntity
    @EnvironmentObject var viewModel: WardrobeViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var selectedCategory: ClothingCategory
    @State private var selectedColor: ClothingColor
    @State private var selectedSeason: Season
    @State private var selectedStyle: Style
    @State private var material: String
    @State private var brand: String
    @State private var tags: String
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    
    init(item: ItemEntity) {
        self.item = item
        _name = State(initialValue: item.displayName)
        _selectedCategory = State(initialValue: item.displayCategory)
        _selectedColor = State(initialValue: item.displayColor)
        _selectedSeason = State(initialValue: item.displaySeason)
        _selectedStyle = State(initialValue: item.displayStyle)
        _material = State(initialValue: item.material ?? "")
        _brand = State(initialValue: item.brand ?? "")
        _tags = State(initialValue: item.tags ?? "")
        if let uiImage = item.uiImage {
            _selectedImage = State(initialValue: uiImage)
        } else {
            _selectedImage = State(initialValue: nil)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Image")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                    }
                }
                
                Section(header: Text("Basic Information")) {
                    TextField("Item Name", text: $name)
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ClothingCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    Picker("Color", selection: $selectedColor) {
                        ForEach(ClothingColor.allCases, id: \.self) { color in
                            Text(color.rawValue).tag(color)
                        }
                    }
                }
                
                Section(header: Text("Style & Season")) {
                    Picker("Season", selection: $selectedSeason) {
                        ForEach(Season.allCases, id: \.self) { season in
                            Text(season.rawValue).tag(season)
                        }
                    }
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(Style.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
                
                Section(header: Text("Additional Information")) {
                    TextField("Material", text: $material)
                    TextField("Brand", text: $brand)
                    TextField("Tags (comma-separated)", text: $tags)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        Task {
            guard let itemId = item.id else { return }
            await viewModel.updateItem(
                id: itemId,
                name: name,
                category: selectedCategory,
                color: selectedColor,
                season: selectedSeason,
                style: selectedStyle,
                image: selectedImage,
                material: material.isEmpty ? nil : material,
                brand: brand.isEmpty ? nil : brand,
                tags: Array(tagArray)
            )
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.viewContext
    let item = ItemEntity(context: context)
    item.id = UUID()
    item.name = "Blue Jeans"
    item.category = ClothingCategory.bottoms.rawValue
    item.color = ClothingColor.blue.rawValue
    item.season = Season.allSeason.rawValue
    item.style = Style.casual.rawValue
    item.dateAdded = Date()
    
    return NavigationView {
        ItemDetailView(item: item)
            .environmentObject(WardrobeViewModel())
    }
    .environment(\.managedObjectContext, context)
}

