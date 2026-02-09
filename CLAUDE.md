# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Wardrobe Assistant is an iOS app for wardrobe management built with SwiftUI and Core Data. Users can organize clothing items, create outfits, receive AI-powered recommendations, track usage analytics, and access premium features via StoreKit 2 subscriptions.

**Tech Stack:**
- Swift 5.9+, SwiftUI
- Core Data for persistence
- StoreKit 2 for subscriptions
- iOS 17.0+ minimum deployment target
- No external dependencies (only Apple frameworks)

## Build & Run Commands

### Building and Running
```bash
# Open project in Xcode
open WardrobeAssistance_v1.1.xcodeproj

# Build from command line (requires Xcode)
xcodebuild -project WardrobeAssistance_v1.1.xcodeproj -scheme WardrobeAssistance_v1.1 -sdk iphonesimulator build

# Run in Xcode: ⌘R
# Build in Xcode: ⌘B
# Clean build folder: ⌘⇧K
```

### Testing
Currently no test targets exist in the project.

## Architecture

### MVVM Pattern
The app follows strict MVVM architecture:

- **Models**: Core Data entities (`ItemEntity`, `OutfitEntity`) with Swift extensions
- **ViewModels**:
  - `WardrobeViewModel` - manages wardrobe items, filtering, search
  - `OutfitViewModel` - manages outfit creation and management
  - `RecommendationViewModel` - handles AI recommendations and weather data
- **Views**: SwiftUI views organized by feature (see Views/ directory)
- **Services**: Data access layer that encapsulates Core Data operations

### Core Data Architecture

**Critical Pattern**: All Core Data write operations MUST happen on background contexts via `PersistenceController.performBackgroundTask()`.

**PersistenceController** (`Persistence.swift`):
- Singleton instance (`PersistenceController.shared`)
- `viewContext` - main context for UI, read-only, auto-merges from parent
- `performBackgroundTask()` - async method for all write operations
- Merge policy: `NSMergeByPropertyObjectTrumpMergePolicy`

**Data Services** (`Services/`):
- `WardrobeDataService` - CRUD operations for `ItemEntity`
- `OutfitDataService` - CRUD operations for `OutfitEntity`
- All operations are async/await
- Handle background context creation and saving internally

**Core Data Entities**:
- `ItemEntity` - clothing items (id, name, category, color, season, style, brand, material, tags, wearCount, isFavorite, dateAdded, lastWorn, imageFileName)
- `OutfitEntity` - outfit combinations (id, name, items array, occasion, season, imageData, notes, dateCreated, isFavorite, lastWorn, wearCount, rating)

### Image Management

**Never store images in Core Data.** Images are stored in the filesystem.

- **ImageFileManager** (`ImageFileManager.swift`) - saves/loads/deletes images from Documents directory as .jpg files
- **ImageCache** (`ImageCache.swift`) - NSCache-based RAM cache (max 100 images, ~50MB)
- **CachedImageView** (`Views/CachedImageView.swift`) - SwiftUI view for async image loading with caching
- `ItemEntity.imageFileName` stores only the UUID filename reference, not the image data

**Pattern for images**:
```swift
// Loading images - use CachedImageView in SwiftUI
CachedImageView(item: item)

// Or async loading programmatically
Task {
    if let image = await item.loadImageAsync() {
        // Use image
    }
}

// NEVER use deprecated synchronous methods:
// - item.uiImage (deprecated)
// - item.swiftUIImage (deprecated)
```

### Memory Management

**Avoid retain cycles**:
- ViewModels are owned by `MainTabView` via `@StateObject`
- `OutfitViewModel` and `RecommendationViewModel` hold strong references to `WardrobeViewModel` - this is safe because they share the same lifecycle
- `AIStyleAssistant` uses `weak var wardrobeViewModel` to prevent retain cycles
- Always use `weak` or `unowned` when referencing ViewModels from service objects that may outlive the view hierarchy

### Subscription/Premium Features

**SubscriptionManager** (`Services/SubscriptionManager.swift`):
- StoreKit 2 implementation using async/await
- Product ID: `wardrobe.premium`
- Handles purchase flow, restoration, entitlement checking
- Injected as `@EnvironmentObject` from app root

**Premium limits**:
- Free tier: 20 wardrobe items maximum
- Premium: unlimited items, AI stylist, advanced analytics, iCloud sync

**Configuration**: StoreKit products must be configured in App Store Connect before testing.

### Design System

**AppDesign** (`DesignSystem.swift`) - centralized design tokens:
- `AppDesign.Spacing` - xs (4), s (8), m (16), l (24), xl (32), xxl (40), xxxl (48)
- `AppDesign.CornerRadius` - small (8), medium (12), large (16), xlarge (20), xxlarge (24)
- `AppDesign.Typography` - rounded font system with semantic sizes
- `AppDesign.Colors` - primary, secondary, accent, success, warning, error, gradients
- Button styles: `PremiumButtonStyle`, `SecondaryButtonStyle`
- View modifier: `.cardStyle()` for consistent card presentation
- **Color(hex:)** extension for hex color support

**Always use design system values** instead of hardcoded numbers.

## Project Structure

```
WardrobeAssistance_v1.1/
├── Models/
│   ├── ClothingEnums.swift      # Category, Season, Style, Color, Occasion enums
│   ├── WeatherData.swift         # Weather model for recommendations
│   └── OnboardingDataModel.swift # Onboarding state
├── Services/
│   ├── WardrobeDataService.swift # ItemEntity CRUD (background context)
│   ├── OutfitDataService.swift   # OutfitEntity CRUD (background context)
│   ├── AIStyleAssistant.swift    # AI stylist (stub implementation)
│   └── SubscriptionManager.swift # StoreKit 2 subscription handling
├── ViewModels/
│   ├── WardrobeViewModel.swift
│   ├── OutfitViewModel.swift
│   └── RecommendationViewModel.swift
├── Views/
│   ├── MainTabView.swift         # Root tab container
│   ├── HomeView.swift / ModernHomeView.swift
│   ├── WardrobeView.swift        # Item list
│   ├── AddItemView.swift         # Add/edit item
│   ├── ItemDetailView.swift      # Item details
│   ├── OutfitBuilderView.swift   # Outfit creation
│   ├── RecommendationsView.swift # AI recommendations
│   ├── AnalyticsView.swift       # Usage statistics
│   ├── CalendarView.swift        # Outfit calendar
│   ├── AIStylistChatView.swift   # AI chat interface
│   ├── PaywallView.swift / ModernPaywallView.swift
│   ├── OnboardingView.swift / SimplifiedOnboardingView.swift
│   ├── SettingsView.swift
│   ├── MoreView.swift
│   ├── FilterView.swift
│   ├── CachedImageView.swift     # Async image loading
│   ├── PrivacyPolicyView.swift
│   └── TermsOfUseView.swift
├── Persistence.swift             # Core Data stack
├── ImageFileManager.swift        # Filesystem image storage
├── ImageCache.swift              # NSCache image caching
├── DesignSystem.swift            # Design tokens and styles
├── ErrorHandling.swift           # Error types
├── ItemEntity+Extensions.swift   # ItemEntity helpers
├── OutfitEntity+Extensions.swift # OutfitEntity helpers
├── WardrobeModel.xcdatamodeld/   # Core Data schema
├── Assets.xcassets/              # Images and colors
└── [lang].lproj/                 # Localizations (en, ru, de, es, fr)
```

## Key Patterns & Conventions

### Async/Await Everywhere
- All Core Data write operations use `async throws`
- All service methods are async
- ViewModels call services with `Task { }` blocks
- UI updates automatically via `@FetchRequest` or manual refresh

### Background Context Pattern
```swift
// CORRECT: Write operation on background context
try await wardrobeDataService.createItem(
    name: "T-Shirt",
    category: .tops,
    color: .blue,
    season: .summer,
    style: .casual
)

// INCORRECT: Never write directly to viewContext from UI
let item = ItemEntity(context: viewContext) // ❌ DON'T DO THIS
```

### Image Handling Pattern
```swift
// CORRECT: Save image through service
try await wardrobeDataService.createItem(..., image: uiImage)

// CORRECT: Display image in UI
CachedImageView(item: item)

// INCORRECT: Direct image access
Image(uiImage: item.uiImage!) // ❌ Deprecated, blocks main thread
```

### ViewModel Injection
ViewModels are created in `MainTabView` and passed to child views:
```swift
// In MainTabView
@StateObject private var wardrobeVM = WardrobeViewModel()
@StateObject private var outfitVM: OutfitViewModel
@StateObject private var recommendationVM: RecommendationViewModel

init() {
    let wardrobeVM = WardrobeViewModel()
    _wardrobeVM = StateObject(wrappedValue: wardrobeVM)
    _outfitVM = StateObject(wrappedValue: OutfitViewModel(wardrobeViewModel: wardrobeVM))
    _recommendationVM = StateObject(wrappedValue: RecommendationViewModel(wardrobeViewModel: wardrobeVM))
}
```

### Localization
Use `NSLocalizedString` for all user-facing text:
```swift
Text(NSLocalizedString("wardrobe.title", comment: ""))
```

Localization files: `en.lproj/Localizable.strings`, `ru.lproj/Localizable.strings`, etc.

## Common Tasks

### Adding a new clothing category
1. Update `ClothingCategory` enum in `Models/ClothingEnums.swift`
2. Add localized strings for the new category
3. Update filter UI in `FilterView.swift` if needed

### Adding a new Core Data entity
1. Open `WardrobeModel.xcdatamodeld` in Xcode
2. Add entity and attributes
3. Create Swift extensions file (e.g., `NewEntity+Extensions.swift`)
4. Create corresponding data service (e.g., `NewEntityDataService.swift`)
5. Update ViewModels to use the new service
6. Consider migration strategy for existing users

### Adding a new premium feature
1. Check entitlement in ViewModel: `subscriptionManager.isPremium`
2. Show paywall if not premium: `showPaywall = true`
3. Update `PaywallView` feature list if needed
4. Test with Sandbox tester accounts in App Store Connect

### Modifying image storage
- Never change `ImageFileManager` to store in Core Data
- Image operations should remain async
- Always update `ImageCache` after filesystem operations

## Performance Considerations

1. **Core Data**: All writes on background context, reads via `@FetchRequest`
2. **Images**:
   - Cached in RAM (NSCache, 100 items max, ~50MB)
   - Loaded asynchronously
   - Never included in Core Data entities
3. **UI**: Use `CachedImageView` to prevent main thread blocking
4. **Memory**: ViewModels are `@StateObject`, services use weak references where needed

## Localization

The app supports 5 languages:
- English (en)
- Russian (ru)
- German (de)
- Spanish (es)
- French (fr)

When adding new user-facing strings, **only update `en.lproj/Localizable.strings`**. Do NOT touch other language files (ru, de, es, fr) unless the user explicitly asks. The user handles translations manually.

## Important Notes

- **Never hardcode colors/spacing** - use `AppDesign` tokens
- **Never write to viewContext** - use data services with background context
- **Never store images in Core Data** - use `ImageFileManager`
- **Never block main thread** - use async/await for I/O operations
- **Always use weak references** when services reference ViewModels
- **Test subscriptions** in Sandbox environment before production
- The app has onboarding flow controlled by `@AppStorage("hasCompletedOnboarding")`
- Privacy usage descriptions are configured in project settings (Camera, Photo Library)

## Recent UI/UX Overhaul (Feb 2026) — DONE

All changes build successfully.

### Completed
- **SideMenuView** (new) — sheet menu with Analytics + Settings, accessible from all tabs via hamburger icon
- **FloatingAddButton** (new) — reusable 56pt gradient FAB, used in HomeView + WardrobeView
- **MainTabView** — replaced "More" tab with "Calendar"; pop-to-root on tab re-tap via custom `Binding` + `.id(UUID)` reset; all tabs now pass `storeKitManager` + `outfitViewModel` for SideMenuView
- **ItemDetailView** — inline editing (Form-based), auto-save on `.onDisappear`, removed `EditItemView` struct, bottom bar: Worn + Delete only
- **WardrobeView** — category filter tags (horizontal capsules), heart overlay on cards (outside NavigationLink via ZStack), FAB, PRO button, menu button, removed FilterView sheet
- **HomeView** — FAB, PRO button, menu button
- **OutfitBuilderView / RecommendationsView / CalendarView** — added menu button + storeKitManager env

### Key patterns introduced
- Heart buttons on cards sit in ZStack **outside** NavigationLink (otherwise tap is swallowed)
- Pop-to-root: custom `Binding<Tab>` setter detects `newTab == selectedTab` → resets UUID → recreates NavigationView
- `MoreView` no longer in tab bar (file still exists)
