//
//  ImageProcessingService.swift
//  WardrobeAssistance_v1.1
//
//  Service for background removal via Supabase Edge Function
//

import UIKit
import Foundation

/// Result of image processing containing the processed image and premium status
struct ImageProcessingResult {
    let image: UIImage
    let isPremium: Bool
}

/// Service for removing image backgrounds via Supabase Edge Function
final class ImageProcessingService {
    static let shared = ImageProcessingService()

    private let supabaseURL = "https://lqpmgnfjwlecgxecuqtg.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxxcG1nbmZqd2xlY2d4ZWN1cXRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyMzMzNjksImV4cCI6MjA4NTgwOTM2OX0.sVby2xt4ZG4nWQnYWC6Grz1x_izx2BdVhxov6a2SvNo"
    private let authService = AuthService.shared
    private let maxImageDimension: CGFloat = 1024
    private let timeoutInterval: TimeInterval = 30

    private init() {}

    /// Processes an image to remove its background
    /// - Parameter image: The source UIImage
    /// - Returns: Processed image with background removed and whether premium processing was used
    func processImage(_ image: UIImage) async throws -> ImageProcessingResult {
        let token = try await authService.getValidToken()

        // Resize image before upload
        let resizedImage = resizeIfNeeded(image)

        guard let imageData = resizedImage.jpegData(compressionQuality: 0.85) else {
            throw ImageProcessingError.invalidImage
        }

        let url = URL(string: "\(supabaseURL)/functions/v1/process-image")!
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageProcessingError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            guard let processedImage = UIImage(data: data) else {
                throw ImageProcessingError.invalidResponse
            }
            let isPremium = httpResponse.value(forHTTPHeaderField: "X-Is-Premium") == "true"
            return ImageProcessingResult(image: processedImage, isPremium: isPremium)

        case 401:
            throw SupabaseAIError.unauthorized

        case 400:
            let errorMessage = parseErrorMessage(from: data)
            throw ImageProcessingError.requestFailed(message: errorMessage)

        case 500...599:
            throw ImageProcessingError.serverError

        default:
            let errorMessage = parseErrorMessage(from: data)
            throw ImageProcessingError.requestFailed(message: errorMessage)
        }
    }

    // MARK: - Private

    private func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size
        let maxDim = max(size.width, size.height)

        guard maxDim > maxImageDimension else { return image }

        let scale = maxImageDimension / maxDim
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func parseErrorMessage(from data: Data) -> String {
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return errorResponse.error ?? "Unknown error"
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

// MARK: - Errors

enum ImageProcessingError: LocalizedError {
    case invalidImage
    case invalidResponse
    case serverError
    case requestFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return NSLocalizedString("image.processing.error.invalid", comment: "Invalid image")
        case .invalidResponse:
            return NSLocalizedString("image.processing.error.response", comment: "Invalid response from server")
        case .serverError:
            return NSLocalizedString("image.processing.error.server", comment: "Server error")
        case .requestFailed(let message):
            return message
        }
    }
}

// MARK: - Data Helper

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
