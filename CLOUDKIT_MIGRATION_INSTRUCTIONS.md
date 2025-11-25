# CloudKit Migration Instructions

## ⚠️ CRITICAL: Manual Steps Required in Xcode

Before the app will compile, you **MUST** update the Core Data model in Xcode.

## Step 1: Update Core Data Model

1. Open `WardrobeModel.xcdatamodeld` in Xcode
2. Select `ItemEntity` entity
3. **REMOVE** the `imageFileName` attribute (if it exists)
4. **ADD** a new attribute:
   - Name: `imageData`
   - Type: `Binary Data`
   - Optional: ✅ YES
   - **CRITICAL**: Check "Allows External Storage" checkbox
     - This is essential for CloudKit performance with large images
5. Select `OutfitEntity` entity
6. Ensure `imageData` attribute exists:
   - Name: `imageData`
   - Type: `Binary Data`
   - Optional: ✅ YES
   - **CRITICAL**: Check "Allows External Storage" checkbox

## Step 2: Configure CloudKit Container

1. In Xcode, select your project target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "CloudKit"
5. Set Container Identifier: `iCloud.com.rafaellatypov.WardrobeAssistant`
   - Or use your own identifier format: `iCloud.com.YOURTEAMID.WardrobeAssistant`

## Step 3: Enable CloudKit in Core Data

The code already configures CloudKit in `Persistence.swift`, but verify:

- `NSPersistentCloudKitContainer` is used (not `NSPersistentContainer`)
- Container identifier matches your CloudKit capability
- `NSPersistentHistoryTrackingKey` is enabled
- `NSPersistentStoreRemoteChangeNotificationPostOptionKey` is enabled

## Step 4: Data Model Requirements

### ItemEntity Required Attributes:
- `id`: UUID (Required)
- `name`: String (Optional)
- `category`: String (Optional)
- `color`: String (Optional)
- `season`: String (Optional)
- `style`: String (Optional)
- `imageData`: Binary Data (Optional, **Allows External Storage** ✅)
- `dateAdded`: Date (Optional)
- `isFavorite`: Boolean (Optional)
- `wearCount`: Integer 32 (Optional)
- `lastWorn`: Date (Optional)
- `material`: String (Optional)
- `brand`: String (Optional)
- `tags`: String (Optional)

### OutfitEntity Required Attributes:
- `id`: UUID (Required)
- `name`: String (Optional)
- `occasion`: String (Optional)
- `season`: String (Optional)
- `imageData`: Binary Data (Optional, **Allows External Storage** ✅)
- `items`: Transformable [UUID] (Optional)
- `dateCreated`: Date (Optional)
- `isFavorite`: Boolean (Optional)
- `wearCount`: Integer 32 (Optional)
- `lastWorn`: Date (Optional)

## Step 5: Remove Old Image Files (Optional)

After migration, you can delete the old image files from disk:
- Location: `Documents/WardrobeImages/`
- These are no longer needed as images are stored in Core Data

## Step 6: Test CloudKit Sync

1. Run the app on two devices with the same iCloud account
2. Add an item on Device 1
3. Wait a few seconds
4. Check Device 2 - the item should appear automatically

## Architecture: Hard Gate Paywall

### Access Control:
- **Has Active Trial/Subscription** → Full app access with iCloud sync
- **No Active Subscription** → Only PaywallView shown, no app access

### Trial Management:
- 7-day free trial starts on first launch
- Trial status stored in UserDefaults
- Trial end date calculated automatically
- `SubscriptionManager.hasFullAccess` controls app access

## Code Changes Summary

✅ **Completed:**
- `Persistence.swift` → Uses `NSPersistentCloudKitContainer`
- `ItemEntity+Extensions.swift` → Uses `imageData` instead of `imageFileName`
- `OutfitEntity+Extensions.swift` → Uses `imageData` with `saveImage()` method
- `WardrobeDataService.swift` → Works directly with `imageData`
- `CachedImageView.swift` → Loads from `imageData`
- `SubscriptionManager.swift` → Added `hasFullAccess`, `hasActiveTrial`, `trialEndDate`
- `WardrobeAssistance_v1_1App.swift` → Hard Gate Paywall model
- `ImageFileManager.swift` → **DELETED** (no longer needed)

## Important Notes

1. **Image Storage**: Images are now stored directly in Core Data as Binary Data
2. **CloudKit Sync**: All data (including images) syncs automatically via CloudKit
3. **Performance**: "Allows External Storage" ensures large images don't bloat the database
4. **Migration**: Existing data with `imageFileName` will need manual migration (not implemented)
5. **Trial**: First launch automatically starts 7-day trial

## Troubleshooting

### Build Errors:
- If you see "no member 'imageData'": Update Core Data model (Step 1)
- If you see CloudKit errors: Check container identifier matches

### CloudKit Sync Issues:
- Ensure iCloud is enabled on device
- Check CloudKit container exists in App Store Connect
- Verify network connection
- Check CloudKit dashboard for errors

### Image Loading Issues:
- Ensure "Allows External Storage" is checked
- Check imageData is not nil
- Verify Core Data context is properly configured

---

**Last Updated:** November 2025
**Status:** ⚠️ Requires manual Core Data model update in Xcode

