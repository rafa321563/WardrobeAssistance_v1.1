//
//  CalendarView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import CoreData

struct CalendarView: View {
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedDate = Date()
    @State private var showingOutfitPicker = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OutfitEntity.lastWorn, ascending: false)],
        animation: .default
    )
    private var outfits: FetchedResults<OutfitEntity>
    
    var plannedOutfits: [Date: OutfitEntity] {
        var plans: [Date: OutfitEntity] = [:]
        for outfit in outfits {
            if let lastWorn = outfit.lastWorn {
                plans[Calendar.current.startOfDay(for: lastWorn)] = outfit
            }
        }
        return plans
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar Header
                CalendarHeader(selectedDate: $selectedDate)
                
                // Calendar Grid
                CalendarGrid(selectedDate: $selectedDate, plannedOutfits: plannedOutfits)
                
                Divider()
                
                // Selected Date Outfit
                if let outfit = plannedOutfits[Calendar.current.startOfDay(for: selectedDate)] {
                    SelectedDateOutfitView(outfit: outfit)
                        .environmentObject(wardrobeViewModel)
                } else {
                    VStack(spacing: 16) {
                        Text("No outfit planned for this date")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button(action: {
                            showingOutfitPicker = true
                        }) {
                            Text("Plan Outfit")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Outfit Calendar")
            .sheet(isPresented: $showingOutfitPicker) {
                OutfitPickerView(selectedDate: selectedDate)
                    .environmentObject(outfitViewModel)
                    .environmentObject(wardrobeViewModel)
            }
        }
    }
}

struct CalendarHeader: View {
    @Binding var selectedDate: Date
    @State private var currentMonth = Date()
    
    var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var body: some View {
        HStack {
            Button(action: {
                currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(monthFormatter.string(from: currentMonth))
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {
                currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
}

struct CalendarGrid: View {
    @Binding var selectedDate: Date
    let plannedOutfits: [Date: OutfitEntity]
    
    let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var daysInMonth: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let numDays = range.count
        let firstDayOfWeek = calendar.component(.weekday, from: startOfMonth)
        
        var days: [Date] = []
        
        // Add padding days
        let paddingDays = (firstDayOfWeek - 1) % 7
        for _ in 0..<paddingDays {
            days.append(Date())
        }
        
        // Add actual days
        for day in 1...numDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            HStack {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        hasOutfit: plannedOutfits[Calendar.current.startOfDay(for: date)] != nil,
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
            .padding()
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasOutfit: Bool
    let isCurrentMonth: Bool
    
    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isCurrentMonth ? (isSelected ? .white : .primary) : .secondary)
            
            if hasOutfit {
                Circle()
                    .fill(isSelected ? Color.white : Color.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 40, height: 40)
        .background(isSelected ? Color.blue : Color.clear)
        .cornerRadius(8)
    }
}

struct SelectedDateOutfitView: View {
    let outfit: OutfitEntity
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var outfitItems: [ItemEntity] {
        outfit.itemsArray.compactMap { id in
            wardrobeViewModel.getItem(by: id, context: viewContext)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planned Outfit")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(outfitItems) { item in
                        VStack(spacing: 8) {
                            ItemThumbnailView(item: item)
                            Text(item.displayName)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 100)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct OutfitPickerView: View {
    let selectedDate: Date
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
            List {
                ForEach(outfits) { outfit in
                    OutfitRowView(outfit: outfit)
                        .environmentObject(wardrobeViewModel)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // In a real app, this would save the outfit to the calendar
                            dismiss()
                        }
                }
            }
            .navigationTitle("Select Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OutfitRowView: View {
    let outfit: OutfitEntity
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var outfitItems: [ItemEntity] {
        outfit.itemsArray.compactMap { id in
            wardrobeViewModel.getItem(by: id, context: viewContext)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            OutfitThumbnailView(outfit: outfit)
                .environmentObject(wardrobeViewModel)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(outfit.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(outfit.displayOccasion.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CalendarView()
        .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
        .environmentObject(WardrobeViewModel())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

