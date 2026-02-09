//
//  ItemDetailView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct ItemDetailView: View {
    @ObservedObject var item: ItemEntity
    @EnvironmentObject var viewModel: WardrobeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteAlert = false

    // Editable state fields
    @State private var name: String
    @State private var selectedCategory: ClothingCategory
    @State private var selectedColor: ClothingColor
    @State private var selectedSeason: Season
    @State private var selectedStyle: Style
    @State private var material: String
    @State private var brand: String
    @State private var selectedSize: String?
    @State private var customSizeText: String
    @State private var tags: String

    private var sizePresets: [String] {
        SizePreset.presets(for: selectedCategory)
    }

    private var resolvedSize: String? {
        if let preset = selectedSize, preset != "__custom__" {
            return preset
        }
        return customSizeText.isEmpty ? nil : customSizeText
    }

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

        let existingSize = item.size
        let presets = SizePreset.presets(for: item.displayCategory)
        if let s = existingSize, !s.isEmpty {
            if presets.contains(s) {
                _selectedSize = State(initialValue: s)
                _customSizeText = State(initialValue: "")
            } else {
                _selectedSize = State(initialValue: "__custom__")
                _customSizeText = State(initialValue: s)
            }
        } else {
            _selectedSize = State(initialValue: nil)
            _customSizeText = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // Image hero
                Section {
                    CachedImageView(item: item)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 350)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .background(
                            item.imageFileName == nil
                                ? AnyView(
                                    Rectangle()
                                        .fill(selectedColor.color.opacity(0.3))
                                        .overlay(
                                            Image(systemName: selectedCategory.icon)
                                                .font(.system(size: 80))
                                                .foregroundColor(selectedColor.color)
                                        )
                                )
                                : AnyView(Color.clear)
                        )
                }

                // Basic Information
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

                // Style & Season
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

                // Size
                Section(header: Text("Size")) {
                    Picker("Size", selection: $selectedSize) {
                        Text("—").tag(String?.none)
                        ForEach(sizePresets, id: \.self) { s in
                            Text(s).tag(String?.some(s))
                        }
                        Text("Custom").tag(String?.some("__custom__"))
                    }
                    if selectedSize == "__custom__" {
                        TextField("Enter your own", text: $customSizeText)
                    }
                }
                .onChange(of: selectedCategory) { _ in
                    if let current = selectedSize, current != "__custom__" {
                        let newPresets = SizePreset.presets(for: selectedCategory)
                        if !newPresets.contains(current) {
                            selectedSize = nil
                            customSizeText = ""
                        }
                    }
                }

                // Additional Information
                Section(header: Text("Additional Information")) {
                    TextField("Material", text: $material)
                    TextField("Brand", text: $brand)
                    TextField("Tags (comma-separated)", text: $tags)
                }

                // Statistics (read-only)
                Section(header: Text("Statistics")) {
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

            // Fixed bottom action bar — Worn + Delete only
            HStack(spacing: AppDesign.Spacing.m) {
                Button {
                    Task {
                        guard let itemId = item.id else { return }
                        await viewModel.markAsWorn(id: itemId)
                    }
                } label: {
                    Label("Worn", systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppDesign.Spacing.s)
                }
                .buttonStyle(.bordered)
                .tint(AppDesign.Colors.primary)

                Button {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppDesign.Spacing.s)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal, AppDesign.Spacing.m)
            .padding(.vertical, AppDesign.Spacing.s)
            .background(.ultraThinMaterial)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            saveChanges()
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

    private func saveChanges() {
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
                image: nil,
                material: material.isEmpty ? nil : material,
                brand: brand.isEmpty ? nil : brand,
                size: resolvedSize,
                tags: Array(tagArray)
            )
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
