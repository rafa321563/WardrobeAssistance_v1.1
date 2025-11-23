//
//  SettingsView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

/// Settings view with subscription management
struct SettingsView: View {
    @EnvironmentObject var storeKitManager: SubscriptionManager
    @State private var showPaywall = false
    @State private var restoreError: String?
    
    var body: some View {
        NavigationView {
            List {
                // Premium Status Section
                Section(header: Text("Subscription")) {
                    HStack {
                        Text("Premium Status")
                        Spacer()
                        if storeKitManager.isPremium {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Inactive", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    if !storeKitManager.isPremium {
                        Button(action: {
                            showPaywall = true
                        }) {
                            HStack {
                                Text("Upgrade to Premium")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                }
                
                // Manage Subscription
                Section(header: Text("Account")) {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                        HStack {
                            Text("Manage Subscription")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await restorePurchases()
                        }
                    }) {
                        HStack {
                            Text("Restore Purchases")
                            Spacer()
                            if storeKitManager.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(storeKitManager.isLoading)
                    
                    if storeKitManager.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    
                    if let error = restoreError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    if let error = storeKitManager.errorMessage, !storeKitManager.isLoading {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // App Info Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Privacy Policy")
                        }
                    }
                    
                    NavigationLink(destination: TermsOfUseView()) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Terms of Use")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeKitManager)
        }
    }
    
    // MARK: - Private Methods
    
    private func restorePurchases() async {
        restoreError = nil
        storeKitManager.errorMessage = nil
        
        do {
            try await storeKitManager.restorePurchases()
            // UI automatically updates via @Published properties
            restoreError = nil
        } catch {
            restoreError = "Failed to restore: \(error.localizedDescription)"
        }
    }
}

#Preview("Light Mode") {
    SettingsView()
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    SettingsView()
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}

