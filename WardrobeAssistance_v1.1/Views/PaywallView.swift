//
//  PaywallView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import StoreKit

/// Premium paywall view with multiple design options
struct PaywallView: View {
    // MARK: - Properties
    
    @EnvironmentObject var storeKitManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDesign: PaywallDesign = .premiumLuxury
    @State private var isPurchasing: Bool = false
    
    /// Current product (premium subscription)
    private var premiumProduct: Product? {
        storeKitManager.products.first { $0.id == SubscriptionManager.premiumProductID }
    }
    
    /// Localized price string
    private var priceString: String {
        guard let product = premiumProduct else {
            return "Loading..."
        }
        return product.displayPrice
    }
    
    /// Subscription period
    private var subscriptionPeriod: String {
        guard let product = premiumProduct,
              let subscription = product.subscription else {
            return "month"
        }
        
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return "month"
        case .year:
            return "year"
        case .week:
            return "week"
        @unknown default:
            return "period"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background based on design
            backgroundView
            
            ScrollView {
                VStack(spacing: 0) {
                    // Close button
                    closeButton
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    // Content
                    contentView
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            Task {
                await storeKitManager.loadProducts()
            }
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        Group {
            switch selectedDesign {
            case .premiumLuxury:
                LinearGradient(
                    colors: [
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e"),
                        Color(hex: "0f3460")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
            case .minimalApple:
                Color(.systemBackground)
                
            case .emotionalModern:
                LinearGradient(
                    colors: [
                        Color(hex: "fef5e7"),
                        Color(hex: "fdebd0"),
                        Color(hex: "fad7a0")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(spacing: 32) {
            // Title
            titleSection
            
            // Price & Trial Section
            priceSection
            
            // Features List
            featuresSection
            
            // CTA Button
            ctaButton
            
            // Subtext
            subtextSection
            
            // Restore Purchases
            restoreButton
            
            // Footer Links
            footerLinks
        }
        .padding(.top, 20)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Wardrobe Premium")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(titleColor)
            
            Text(localizedSubtitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(subtitleColor)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Price Section
    
    private var priceSection: some View {
        VStack(spacing: 16) {
            if let product = premiumProduct,
               let subscription = product.subscription {
                // Free trial badge
                if subscription.introductoryOffer != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.yellow)
                        Text("Start 7-Day FREE Trial")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.yellow.opacity(0.2))
                    )
                }
                
                // Price
                VStack(spacing: 4) {
                    Text("Then \(priceString) / \(subscriptionPeriod)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Cancel anytime — no charges until the trial ends")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(premiumFeatures, id: \.title) { feature in
                FeatureRow(feature: feature, design: selectedDesign)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(featureCardBackground)
                .shadow(color: Color.primary.opacity(0.15), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        Button(action: {
            Task {
                await purchasePremium()
            }
        }) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(ctaButtonText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    // Градиентный фон
                    LinearGradient(
                        colors: ctaButtonColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    // Темный оверлей для улучшения контрастности белого текста
                    Color.black.opacity(0.15)
                }
            )
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.2), radius: 15, x: 0, y: 8)
        }
        .disabled(isPurchasing || premiumProduct == nil)
    }
    
    // MARK: - Subtext Section
    
    private var subtextSection: some View {
        Text("Then \(priceString) per month · Cancel anytime")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button(action: {
            Task {
                await storeKitManager.restore()
            }
        }) {
            Text("Restore Purchases")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Footer Links
    
    private var footerLinks: some View {
        HStack(spacing: 20) {
            Link("Privacy Policy", destination: URL(string: "https://yourwebsite.com/privacy")!)
            Text("·")
            Link("Terms of Use", destination: URL(string: "https://yourwebsite.com/terms")!)
        }
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
    
    // MARK: - Premium Features
    
    private var premiumFeatures: [PremiumFeatureItem] {
        [
            PremiumFeatureItem(
                icon: "infinity",
                title: "Unlimited wardrobe items",
                titleLocalized: "Неограниченное количество вещей"
            ),
            PremiumFeatureItem(
                icon: "sparkles",
                title: "AI stylist (full access)",
                titleLocalized: "AI-стилист (полный доступ)"
            ),
            PremiumFeatureItem(
                icon: "wand.and.stars",
                title: "Smart outfit matching",
                titleLocalized: "Умный подбор образов"
            ),
            PremiumFeatureItem(
                icon: "chart.bar.fill",
                title: "Advanced analytics",
                titleLocalized: "Расширенная аналитика"
            ),
            PremiumFeatureItem(
                icon: "icloud.fill",
                title: "iCloud sync (Premium)",
                titleLocalized: "Синхронизация iCloud (Premium)"
            ),
            PremiumFeatureItem(
                icon: "star.fill",
                title: "Priority updates & new features",
                titleLocalized: "Приоритетные обновления и новые функции"
            )
        ]
    }
    
    // MARK: - Design Colors
    
    private var titleColor: Color {
        switch selectedDesign {
        case .premiumLuxury:
            return .white
        case .minimalApple:
            return .primary
        case .emotionalModern:
            return Color(hex: "2c3e50")
        }
    }
    
    private var subtitleColor: Color {
        switch selectedDesign {
        case .premiumLuxury:
            return .white.opacity(0.8)
        case .minimalApple:
            return .secondary
        case .emotionalModern:
            return Color(hex: "34495e")
        }
    }
    
    private var featureCardBackground: Color {
        switch selectedDesign {
        case .premiumLuxury:
            return Color.white.opacity(0.1)
        case .minimalApple:
            return Color(.systemBackground)
        case .emotionalModern:
            return Color.white.opacity(0.7)
        }
    }
    
    private var ctaButtonColors: [Color] {
        switch selectedDesign {
        case .premiumLuxury:
            return [Color(hex: "f39c12"), Color(hex: "e67e22")]
        case .minimalApple:
            return [Color.blue, Color.blue.opacity(0.8)]
        case .emotionalModern:
            return [Color(hex: "3498db"), Color(hex: "2980b9")]
        }
    }
    
    private var localizedSubtitle: String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        switch locale {
        case "ru":
            return "Премиум функции для вашего гардероба"
        default:
            return "Unlock premium features for your wardrobe"
        }
    }
    
    private var ctaButtonText: String {
        if premiumProduct?.subscription?.introductoryOffer != nil {
            return "Start 7-Day FREE Trial"
        }
        return "Subscribe to Premium"
    }
    
    // MARK: - Actions
    
    private func purchasePremium() async {
        guard let product = premiumProduct else {
            return
        }
        
        isPurchasing = true
        
        do {
            _ = try await storeKitManager.purchase(product)
            // If purchase successful, dismiss
            if storeKitManager.isPremium {
                dismiss()
            }
        } catch {
            print("❌ PaywallView: Purchase failed - \(error)")
        }
        
        isPurchasing = false
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let feature: PremiumFeatureItem
    let design: PaywallDesign
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(featureIconColor)
                .frame(width: 40, height: 40)
            
            Text(getLocalizedTitle())
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private var featureIconColor: Color {
        switch design {
        case .premiumLuxury:
            return Color(hex: "f39c12")
        case .minimalApple:
            return .blue
        case .emotionalModern:
            return Color(hex: "3498db")
        }
    }
    
    private func getLocalizedTitle() -> String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return locale == "ru" ? feature.titleLocalized : feature.title
    }
}

// MARK: - Premium Feature Item

struct PremiumFeatureItem {
    let icon: String
    let title: String
    let titleLocalized: String
}

// MARK: - Paywall Design

enum PaywallDesign {
    case premiumLuxury
    case minimalApple
    case emotionalModern
}

// MARK: - Preview

#Preview("Light Mode") {
    PaywallView()
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    PaywallView()
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    PaywallView()
        .environmentObject(SubscriptionManager())
        .environment(\.sizeCategory, .accessibilityLarge)
}

