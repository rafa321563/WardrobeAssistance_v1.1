//
//  FilterView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

struct FilterView: View {
    @EnvironmentObject var viewModel: WardrobeViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category")) {
                    Picker("Category", selection: Binding(
                        get: { viewModel.selectedCategory ?? .tops },
                        set: { viewModel.selectedCategory = $0 == .tops ? nil : $0 }
                    )) {
                        Text("All").tag(ClothingCategory.tops)
                        ForEach(ClothingCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section(header: Text("Color")) {
                    Picker("Color", selection: Binding(
                        get: { viewModel.selectedColor ?? .black },
                        set: { viewModel.selectedColor = $0 == .black ? nil : $0 }
                    )) {
                        Text("All").tag(ClothingColor.black)
                        ForEach(ClothingColor.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)
                                Text(color.rawValue)
                            }
                            .tag(color)
                        }
                    }
                }
                
                Section(header: Text("Season")) {
                    Picker("Season", selection: Binding(
                        get: { viewModel.selectedSeason ?? .allSeason },
                        set: { viewModel.selectedSeason = $0 == .allSeason ? nil : $0 }
                    )) {
                        Text("All").tag(Season.allSeason)
                        ForEach(Season.allCases.filter { $0 != .allSeason }, id: \.self) { season in
                            Text(season.rawValue).tag(season)
                        }
                    }
                }
                
                Section(header: Text("Style")) {
                    Picker("Style", selection: Binding(
                        get: { viewModel.selectedStyle ?? .casual },
                        set: { viewModel.selectedStyle = $0 == .casual ? nil : $0 }
                    )) {
                        Text("All").tag(Style.casual)
                        ForEach(Style.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
                
                Section(header: Text("Options")) {
                    Toggle("Favorites Only", isOn: $viewModel.showFavoritesOnly)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FilterView()
        .environmentObject(WardrobeViewModel())
}

