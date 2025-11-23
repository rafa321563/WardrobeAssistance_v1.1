//
//  SubscriptionManager.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation
import StoreKit
import SwiftUI
import Combine

/// Manager for handling StoreKit 2 subscriptions
@MainActor
class SubscriptionManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Current premium subscription status
    @Published var isPremium: Bool = false
    
    /// Available products from StoreKit
    @Published var products: [Product] = []
    
    /// Current subscription status
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    
    /// Error message if any
    @Published var errorMessage: String?
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    // MARK: - Constants
    
    /// Product ID for premium subscription
    static let premiumProductID = "wardrobe.premium"
    
    // MARK: - Private Properties
    
    /// Task for listening to transaction updates
    private var updateListenerTask: Task<Void, Error>?
    
    /// Persisted premium status
    @AppStorage("isPremium") private var persistedIsPremium: Bool = false
    
    // MARK: - Initialization
    
    init() {
        // Restore persisted premium status
        isPremium = persistedIsPremium
        
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Load available products from StoreKit
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = [Self.premiumProductID]
            let storeProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.products = storeProducts
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ SubscriptionManager: Failed to load products - \(error)")
        }
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Update premium status
                await updatePremiumStatus()
                
                // Finish the transaction
                await transaction.finish()
                
                await MainActor.run {
                    self.isLoading = false
                }
                
                return transaction
                
            case .userCancelled:
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Purchase was cancelled"
                }
                return nil
                
            case .pending:
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Purchase is pending approval"
                }
                return nil
                
            @unknown default:
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Unknown purchase result"
                }
                return nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Purchase failed: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    /// Restore previous purchases
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            }
            print("❌ SubscriptionManager: Failed to restore - \(error)")
            throw error
        }
    }
    
    /// Legacy method for backward compatibility
    func restore() async {
        do {
            try await restorePurchases()
        } catch {
            // Error already handled in restorePurchases
        }
    }
    
    /// Check current subscription status
    func checkSubscriptionStatus() async {
        var isCurrentlyPremium = false
        
        // Check current entitlements
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if this is our premium product
                if transaction.productID == Self.premiumProductID {
                    // Check if subscription is still active
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            isCurrentlyPremium = true
                        }
                    } else {
                        // Non-consumable or lifetime subscription
                        isCurrentlyPremium = true
                    }
                }
            } catch {
                print("❌ SubscriptionManager: Failed to verify transaction - \(error)")
            }
        }
        
        await MainActor.run {
            self.isPremium = isCurrentlyPremium
            self.persistedIsPremium = isCurrentlyPremium
            
            if isCurrentlyPremium {
                self.subscriptionStatus = .active
            } else {
                self.subscriptionStatus = .inactive
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self.checkVerifiedAsync(result)
                    
                    // Update premium status
                    await self.updatePremiumStatus()
                    
                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("❌ SubscriptionManager: Transaction verification failed - \(error)")
                }
            }
        }
    }
    
    /// Check verified (async version for detached tasks)
    private func checkVerifiedAsync<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    /// Update premium status based on current entitlements
    private func updatePremiumStatus() async {
        await checkSubscriptionStatus()
    }
    
    /// Verify a StoreKit transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Premium Feature Gating
    
    /// Check if feature is available
    func isFeatureAvailable(_ feature: PremiumFeature) -> Bool {
        if isPremium {
            return true
        }
        
        // Some features might be available in free tier
        switch feature {
        case .unlimitedItems:
            return false
        case .aiStylist:
            return false
        case .smartMatching:
            return false
        case .advancedAnalytics:
            return false
        case .iCloudSync:
            return false
        case .priorityUpdates:
            return false
        }
    }
    
    /// Get feature limit for free tier
    func getFreeTierLimit(_ feature: PremiumFeature) -> Int {
        switch feature {
        case .unlimitedItems:
            return 20 // Free tier: 20 items max
        case .aiStylist:
            return 0
        case .smartMatching:
            return 0
        case .advancedAnalytics:
            return 0
        case .iCloudSync:
            return 0
        case .priorityUpdates:
            return 0
        }
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus {
    case unknown
    case active
    case inactive
    case expired
    case revoked
}

// MARK: - Premium Features

enum PremiumFeature {
    case unlimitedItems
    case aiStylist
    case smartMatching
    case advancedAnalytics
    case iCloudSync
    case priorityUpdates
}

