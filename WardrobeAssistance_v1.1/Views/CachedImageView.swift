//
//  CachedImageView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import UIKit
import CoreData

/// SwiftUI view that asynchronously loads and caches images from ItemEntity
/// Uses ImageCache for RAM caching and ImageFileManager for disk access
struct CachedImageView: View {
    let item: ItemEntity
    
    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = false
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
            } else {
                // Placeholder when no image is available
                Image(systemName: "tshirt.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray.opacity(0.3))
                    .padding()
            }
        }
        .task(id: item.id?.uuidString ?? "") {
            await loadImage()
        }
    }
    
    /// Asynchronously loads the image using ItemEntity's loadImageAsync method
    private func loadImage() async {
     //   guard let itemId = item.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Use the async loading method from ItemEntity
        loadedImage = await item.loadImageAsync()
    }
}

/// Preview provider for CachedImageView
#Preview {
    CachedImageView(item: ItemEntity())
        .frame(width: 200, height: 200)
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

