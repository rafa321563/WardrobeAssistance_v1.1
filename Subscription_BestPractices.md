# Subscription Best Practices & Guidelines

## Apple Subscriber Experience Guidelines

### Core Principles

1. **Transparency**
   - Clearly display subscription pricing
   - Show trial period duration prominently
   - Explain auto-renewal clearly
   - Make cancellation easy to find

2. **No Dark Patterns**
   - Don't hide pricing information
   - Don't make cancellation difficult
   - Don't use misleading language
   - Don't auto-enroll without clear consent

3. **Value Communication**
   - Explain what users get with Premium
   - Show benefits clearly
   - Highlight exclusive features
   - Demonstrate value before asking for payment

## StoreKit 2 Implementation

### Transaction Flow Diagram

```
User Initiates Purchase
    ↓
Product.purchase() called
    ↓
StoreKit shows system dialog
    ↓
User approves/cancels
    ↓
Transaction result returned
    ↓
Verify transaction (checkVerified)
    ↓
Update premium status
    ↓
Finish transaction
    ↓
Update UI
```

### Entitlement Verification Flow

```
App Launch
    ↓
Check Transaction.currentEntitlements
    ↓
Verify each transaction
    ↓
Check expiration date
    ↓
Update isPremium status
    ↓
Listen for Transaction.updates
    ↓
Handle renewals/revocations
```

## Best Practices Checklist

### ✅ DO

- [x] Use async/await for all StoreKit operations
- [x] Verify all transactions before trusting them
- [x] Finish transactions after processing
- [x] Listen for transaction updates
- [x] Handle all purchase result cases
- [x] Provide restore purchases option
- [x] Show clear pricing information
- [x] Display trial period prominently
- [x] Explain auto-renewal clearly
- [x] Make cancellation instructions accessible
- [x] Handle network errors gracefully
- [x] Provide loading states during purchase
- [x] Show error messages clearly
- [x] Test in Sandbox environment
- [x] Test subscription renewal flow
- [x] Test cancellation flow
- [x] Test restore purchases
- [x] Handle revoked entitlements
- [x] Persist premium status locally
- [x] Verify status on app launch

### ❌ DON'T

- [ ] Block main thread with StoreKit calls
- [ ] Trust unverified transactions
- [ ] Forget to finish transactions
- [ ] Hide pricing information
- [ ] Make cancellation difficult
- [ ] Use misleading trial language
- [ ] Auto-enroll without consent
- [ ] Charge without clear indication
- [ ] Ignore transaction updates
- [ ] Skip entitlement verification
- [ ] Hardcode product IDs incorrectly
- [ ] Forget error handling
- [ ] Use deprecated StoreKit 1 APIs

## Testing Guidelines

### Sandbox Testing

1. **Create Sandbox Tester Account**
   - Go to App Store Connect
   - Users and Access → Sandbox Testers
   - Create test account

2. **Test Scenarios**
   - Initial purchase
   - Free trial start
   - Trial expiration
   - Subscription renewal
   - Cancellation
   - Restore purchases
   - Network failures
   - Invalid receipts

3. **Sandbox Environment**
   - Sign out of production Apple ID
   - Use Sandbox tester credentials
   - Test on device (not simulator)
   - Check transaction status in App Store Connect

### TestFlight Testing

- Test with real TestFlight users
- Verify subscription flow works
- Test restore purchases
- Check entitlement verification
- Test on different devices

## Handling Edge Cases

### Revoked Entitlements

```swift
// Check if subscription was revoked
if transaction.revocationDate != nil {
    // User's subscription was revoked
    isPremium = false
}
```

### Expired Subscriptions

```swift
// Check expiration date
if let expirationDate = transaction.expirationDate {
    if expirationDate < Date() {
        // Subscription expired
        isPremium = false
    }
}
```

### Pending Purchases

```swift
case .pending:
    // Purchase requires approval (e.g., Ask to Buy)
    // Show appropriate message to user
    showPendingMessage = true
```

### Network Errors

```swift
catch {
    // Handle network or other errors
    errorMessage = "Purchase failed. Please check your connection."
}
```

## Privacy & Compliance

### Data Collection

- Only collect necessary data
- Don't share subscription data with third parties
- Store subscription status locally
- Use StoreKit 2 for verification (no server needed)

### GDPR Compliance

- Clear privacy policy
- User consent for data processing
- Right to deletion
- Data portability

### CCPA Compliance

- Clear data collection disclosure
- Opt-out options
- No sale of personal information

## App Store Review Guidelines

### Subscription Requirements

1. **Clear Value Proposition**
   - Explain what Premium provides
   - Show benefits clearly
   - Justify subscription price

2. **Trial Period**
   - Clearly state trial duration
   - Explain when charges begin
   - Make cancellation easy

3. **Auto-Renewal**
   - Explain auto-renewal clearly
   - Show renewal price
   - Provide cancellation instructions

4. **Restore Purchases**
   - Must be accessible
   - Should work across devices
   - Handle all scenarios

### Common Rejection Reasons

- Unclear pricing
- Hidden cancellation
- Misleading trial language
- Missing restore purchases
- Poor value proposition
- Dark patterns

## Code Examples

### Proper Transaction Verification

```swift
private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified(_, let error):
        throw error
    case .verified(let safe):
        return safe
    }
}
```

### Proper Transaction Finishing

```swift
let transaction = try checkVerified(verification)
// Update app state
await updatePremiumStatus()
// Finish transaction
await transaction.finish()
```

### Listening for Updates

```swift
for await result in Transaction.updates {
    let transaction = try checkVerified(result)
    await updatePremiumStatus()
    await transaction.finish()
}
```

## Monitoring & Analytics

### Key Metrics to Track

- Subscription conversion rate
- Trial-to-paid conversion
- Churn rate
- Average revenue per user (ARPU)
- Lifetime value (LTV)

### Error Tracking

- Failed purchase attempts
- Network errors
- Verification failures
- User cancellations

## Support & Customer Service

### Common Issues

1. **"I was charged but don't have Premium"**
   - Check transaction status
   - Verify entitlement
   - Restore purchases
   - Contact Apple if needed

2. **"How do I cancel?"**
   - Provide clear instructions
   - Link to App Store settings
   - Explain cancellation timing

3. **"Can I get a refund?"**
   - Direct to Apple's refund process
   - Provide reportaproblem.apple.com link
   - Explain refund policy

## Resources

- [Apple StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Subscriber Experience Guidelines](https://developer.apple.com/app-store/subscriptions/)
- [StoreKit Testing Guide](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)

