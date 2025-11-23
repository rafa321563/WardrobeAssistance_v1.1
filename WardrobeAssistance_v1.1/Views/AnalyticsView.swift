//
//  AnalyticsView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct AnalyticsView: View {
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.wearCount, ascending: false)],
        animation: .default
    )
    private var allItems: FetchedResults<ItemEntity>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OutfitEntity.dateCreated, ascending: false)],
        animation: .default
    )
    private var allOutfits: FetchedResults<OutfitEntity>
    
    var totalWears: Int {
        allItems.reduce(0) { $0 + Int($1.wearCount) }
    }
    
    var averageWears: Double {
        guard !allItems.isEmpty else { return 0 }
        return Double(totalWears) / Double(allItems.count)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overview Stats
                    OverviewStatsSection(
                        itemCount: allItems.count,
                        outfitCount: allOutfits.count,
                        totalWears: totalWears,
                        averageWears: averageWears
                    )
                    
                    // Most Worn Items
                    MostWornSection()
                        .environmentObject(wardrobeViewModel)
                    
                    // Least Worn Items
                    LeastWornSection()
                        .environmentObject(wardrobeViewModel)
                    
                    // Category Distribution
                    CategoryDistributionSection(items: Array(allItems))
                    
                    // Style Distribution
                    StyleDistributionSection(items: Array(allItems))
                }
                .padding()
            }
            .navigationTitle("Analytics")
        }
    }
}

struct OverviewStatsSection: View {
    let itemCount: Int
    let outfitCount: Int
    let totalWears: Int
    let averageWears: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatBox(title: "Total Items", value: "\(itemCount)", icon: "tshirt.fill", color: .blue)
                StatBox(title: "Total Outfits", value: "\(outfitCount)", icon: "square.grid.2x2.fill", color: .purple)
            }
            
            HStack(spacing: 16) {
                StatBox(title: "Total Wears", value: "\(totalWears)", icon: "checkmark.circle.fill", color: .green)
                StatBox(title: "Avg. Wears", value: String(format: "%.1f", averageWears), icon: "chart.bar.fill", color: .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct StatBox: View {
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
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct MostWornSection: View {
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var mostWorn: [ItemEntity] {
        wardrobeViewModel.getMostWornItems(limit: 5, context: viewContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Most Worn Items")
                    .font(.headline)
            }
            
            if mostWorn.isEmpty {
                Text("No items have been worn yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(mostWorn) { item in
                    HStack(spacing: 12) {
                        ItemThumbnailView(item: item)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Worn \(item.wearCount) times")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct LeastWornSection: View {
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var leastWorn: [ItemEntity] {
        wardrobeViewModel.getLeastWornItems(limit: 5, context: viewContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Least Worn Items")
                    .font(.headline)
            }
            
            if leastWorn.isEmpty {
                Text("All items have been worn.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(leastWorn) { item in
                    HStack(spacing: 12) {
                        ItemThumbnailView(item: item)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Worn \(item.wearCount) times")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct CategoryDistributionSection: View {
    let items: [ItemEntity]
    
    var categoryDistribution: [ClothingCategory: Int] {
        Dictionary(grouping: items, by: { $0.displayCategory })
            .mapValues { $0.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Distribution")
                .font(.headline)
            
            ForEach(Array(categoryDistribution.sorted(by: { $0.value > $1.value })), id: \.key) { category, count in
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text(category.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct StyleDistributionSection: View {
    let items: [ItemEntity]
    
    var styleDistribution: [Style: Int] {
        Dictionary(grouping: items, by: { $0.displayStyle })
            .mapValues { $0.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Style Distribution")
                .font(.headline)
            
            ForEach(Array(styleDistribution.sorted(by: { $0.value > $1.value })), id: \.key) { style, count in
                HStack {
                    Text(style.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(WardrobeViewModel())
        .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

