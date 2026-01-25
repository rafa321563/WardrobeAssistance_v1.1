//
//  ModernPaywallView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import StoreKit

struct ModernPaywallView: View {
    @EnvironmentObject var storeKit: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedPlan: Plan = .annual
    @State private var isProcessing = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    
    enum Plan: String, CaseIterable {
        case annual = "Annual"
        case monthly = "Monthly"
        
        var savings: String {
            self == .annual ? "Save 40%" : ""
        }
    }
    
    var premiumProduct: Product? {
        storeKit.products.first { $0.id == SubscriptionManager.premiumProductID }
    }
    
    var priceString: String {
        guard let product = premiumProduct else { return "Loading..." }
        return product.displayPrice
    }
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: colorScheme == .dark 
                    ? [Color(hex: "1a1a2e"), Color(hex: "0f3460")]
                    : [Color(hex: "f8f9fa"), Color(hex: "e9ecef")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 60)
                    
                    // Features Grid
                    featuresGrid
                        .padding(.vertical, AppDesign.Spacing.xl)
                    
                    // Plan Selector
                    planSelector
                        .padding(.horizontal, AppDesign.Spacing.l)
                    
                    // CTA Button
                    ctaButton
                        .padding(.horizontal, AppDesign.Spacing.l)
                        .padding(.top, AppDesign.Spacing.xl)
                    
                    // Legal Footer
                    legalFooter
                        .padding(.top, AppDesign.Spacing.l)
                        .padding(.bottom, AppDesign.Spacing.xl)
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Close")
                    }
                    .padding(AppDesign.Spacing.l)
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                await storeKit.loadProducts()
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationView {
                PrivacyPolicyView()
            }
        }
        .sheet(isPresented: $showTerms) {
            NavigationView {
                TermsOfUseView()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.m) {
            ZStack {
                Circle()
                    .fill(AppDesign.Colors.premiumGradient)
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(AppDesign.Colors.premiumGradient)
            }
            
            Text("Wardrobe Premium")
                .font(AppDesign.Typography.largeTitle)
            
            Text("Unlock your style potential")
                .font(AppDesign.Typography.body)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Features Grid
    private var featuresGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppDesign.Spacing.m),
                GridItem(.flexible(), spacing: AppDesign.Spacing.m)
            ],
            spacing: AppDesign.Spacing.m
        ) {
            FeatureCard(icon: "infinity", title: "Unlimited Items", color: .blue)
            FeatureCard(icon: "sparkles", title: "AI Stylist", color: .purple)
            FeatureCard(icon: "chart.bar.fill", title: "Analytics", color: .green)
            FeatureCard(icon: "icloud.fill", title: "Cloud Sync", color: .orange)
        }
        .padding(.horizontal, AppDesign.Spacing.l)
    }
    
    // MARK: - Plan Selector
    private var planSelector: some View {
        VStack(spacing: AppDesign.Spacing.m) {
            ForEach(Plan.allCases, id: \.self) { plan in
                PlanCard(
                    plan: plan,
                    price: getPriceForPlan(plan),
                    isSelected: selectedPlan == plan,
                    action: {
                        withAnimation(.spring()) {
                            selectedPlan = plan
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - CTA Button
    private var ctaButton: some View {
        Button(action: {
            Task { await purchase() }
        }) {
            HStack(spacing: AppDesign.Spacing.s) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Start 7-Day Free Trial")
                        .font(AppDesign.Typography.bodyBold)
                    Image(systemName: "arrow.right")
                }
            }
        }
        .buttonStyle(PremiumButtonStyle(isLoading: isProcessing))
        .disabled(isProcessing)
    }
    
    // MARK: - Legal Footer
    private var legalFooter: some View {
        VStack(spacing: AppDesign.Spacing.m) {
            Text("Then \(priceString). Cancel anytime.")
                .font(AppDesign.Typography.footnote)
                .foregroundColor(.secondary)
            
            HStack(spacing: AppDesign.Spacing.m) {
                Button("Restore") {
                    Task { await storeKit.restore() }
                }
                Text("•").foregroundColor(.secondary)
                Button("Privacy") {
                    showPrivacyPolicy = true
                }
                Text("•").foregroundColor(.secondary)
                Button("Terms") {
                    showTerms = true
                }
            }
            .font(AppDesign.Typography.footnote)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    private func getPriceForPlan(_ plan: Plan) -> String {
        guard let product = premiumProduct else {
            return plan == .annual ? "$29.99/year" : "$4.99/month"
        }
        
        if let subscription = product.subscription {
            let period = subscription.subscriptionPeriod.unit
            if plan == .annual && period == .year {
                return product.displayPrice + "/year"
            } else if plan == .monthly && period == .month {
                return product.displayPrice + "/month"
            }
        }
        
        return plan == .annual ? "$29.99/year" : "$4.99/month"
    }
    
    private func purchase() async {
        isProcessing = true
        defer { isProcessing = false }
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        guard let product = premiumProduct else { return }
        
        do {
            _ = try await storeKit.purchase(product)
            await MainActor.run {
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)
                if storeKit.isPremium {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                let errorGenerator = UINotificationFeedbackGenerator()
                errorGenerator.notificationOccurred(.error)
            }
            print("Purchase failed: \(error)")
        }
    }
}

// MARK: - Feature Card Component

struct FeatureCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.s) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(AppDesign.Typography.captionBold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(.ultraThinMaterial)
        .cornerRadius(AppDesign.CornerRadius.large)
    }
}

// MARK: - Plan Card Component

struct PlanCard: View {
    let plan: ModernPaywallView.Plan
    let price: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.rawValue)
                        .font(AppDesign.Typography.headline)
                    Text(price)
                        .font(AppDesign.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !plan.savings.isEmpty {
                    Text(plan.savings)
                        .font(AppDesign.Typography.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppDesign.Colors.success)
                        .cornerRadius(12)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppDesign.Colors.primary : .secondary)
                    .font(.title3)
            }
            .padding(AppDesign.Spacing.l)
            .background(
                isSelected 
                    ? AppDesign.Colors.primary.opacity(0.1) 
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.large)
                    .stroke(
                        isSelected ? AppDesign.Colors.primary : Color.secondary.opacity(0.3),
                        lineWidth: 2
                    )
            )
            .cornerRadius(AppDesign.CornerRadius.large)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ModernPaywallView()
        .environmentObject(SubscriptionManager())
}

