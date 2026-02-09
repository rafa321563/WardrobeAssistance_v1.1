//
//  SideMenuView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 10.02.26.
//

import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @EnvironmentObject var outfitViewModel: OutfitViewModel
    @EnvironmentObject var storeKitManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Insights") {
                    NavigationLink {
                        AnalyticsView()
                            .environmentObject(wardrobeViewModel)
                            .environmentObject(outfitViewModel)
                    } label: {
                        Label("Analytics", systemImage: "chart.bar.fill")
                    }
                }

                Section("Account") {
                    NavigationLink {
                        SettingsView()
                            .environmentObject(storeKitManager)
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("Menu")
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
