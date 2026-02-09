//
//  ImageFileManager.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import UIKit
import Foundation

/// Singleton service for managing clothing item images on disk
/// Images are stored in the app's Documents directory, not in Core Data
final class ImageFileManager {
    static let shared = ImageFileManager()
    
    private let fileManager = FileManager.default
    private let imagesDirectory: URL
    
    private init() {
        // Get Documents directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imagesDirectory = documentsPath.appendingPathComponent("WardrobeImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        createDirectoryIfNeeded()
    }
    
    // MARK: - Directory Management
    
    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: imagesDirectory.path) else { return }
        
        do {
            try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create images directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save Image
    
    /// Saves an image to disk and returns the filename
    /// - Parameter image: The UIImage to save
    /// - Returns: The filename (UUID) that can be stored in Core Data, or nil if save failed
    @discardableResult
    func saveImage(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to JPEG data")
            return nil
        }
        
        let filename = UUID().uuidString + ".jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save image to disk: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Save Image as PNG

    /// Saves an image as PNG (preserves transparency) and returns the filename
    /// - Parameter image: The UIImage to save
    /// - Returns: The filename (UUID.png) that can be stored in Core Data, or nil if save failed
    @discardableResult
    func saveImageAsPNG(_ image: UIImage) -> String? {
        guard let imageData = image.pngData() else {
            print("Failed to convert image to PNG data")
            return nil
        }

        let filename = UUID().uuidString + ".png"
        let fileURL = imagesDirectory.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save PNG image to disk: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Load Image
    
    /// Loads an image from disk by filename
    /// - Parameter filename: The filename stored in Core Data
    /// - Returns: The UIImage if found, nil otherwise
    func loadImage(filename: String?) -> UIImage? {
        guard let filename = filename else { return nil }
        
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        guard let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    // MARK: - Delete Image
    
    /// Deletes an image file from disk
    /// - Parameter filename: The filename to delete
    func deleteImage(filename: String?) {
        guard let filename = filename else { return }
        
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("Failed to delete image file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Image URL (for AsyncImage if needed)
    
    /// Returns the file URL for an image (useful for AsyncImage)
    /// - Parameter filename: The filename stored in Core Data
    /// - Returns: The file URL if the file exists, nil otherwise
    func imageURL(filename: String?) -> URL? {
        guard let filename = filename else { return nil }
        
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return fileURL
    }
}

