//
//  MoreView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject var storeKitManager: SubscriptionManager
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Analytics")) {
                    NavigationLink(destination: AnalyticsView()
                        .environmentObject(wardrobeViewModel)
                        .environmentObject(outfitViewModel)) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Analytics")
                        }
                    }
                }
                
                Section(header: Text("Planning")) {
                    NavigationLink(destination: CalendarView()
                        .environmentObject(wardrobeViewModel)
                        .environmentObject(outfitViewModel)) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Calendar")
                        }
                    }
                }
                
                Section(header: Text("Account")) {
                    NavigationLink(destination: SettingsView()
                        .environmentObject(storeKitManager)) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            Text("Settings")
                        }
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    MoreView()
        .environmentObject(SubscriptionManager())
        .environmentObject(WardrobeViewModel())
        .environmentObject(OutfitViewModel(wardrobeViewModel: WardrobeViewModel()))
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

