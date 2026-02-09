//
//  ClothingAnalysisService.swift
//  WardrobeAssistance_v1.1
//
//  AI-powered clothing photo analysis via Supabase Edge Function
//

import UIKit
import Foundation

// MARK: - Analysis Result

struct ClothingAnalysisResult {
    var category: ClothingCategory?
    var brand: String?
    var name: String?
    var color: ClothingColor?
    var season: Season?
    var style: Style?
    var material: String?
    var size: String?
    var tags: [String]?
}

// MARK: - Service

final class ClothingAnalysisService {
    static let shared = ClothingAnalysisService()

    private let supabaseURL = "https://lqpmgnfjwlecgxecuqtg.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxxcG1nbmZqd2xlY2d4ZWN1cXRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyMzMzNjksImV4cCI6MjA4NTgwOTM2OX0.sVby2xt4ZG4nWQnYWC6Grz1x_izx2BdVhxov6a2SvNo"
    private let authService = AuthService.shared
    private let maxImageDimension: CGFloat = 1024
    private let timeoutInterval: TimeInterval = 30

    private init() {}

    /// Analyzes a clothing photo and returns structured metadata
    func analyzeImage(_ image: UIImage) async throws -> ClothingAnalysisResult {
        let token = try await authService.getValidToken()

        let resizedImage = resizeIfNeeded(image)

        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw ClothingAnalysisError.invalidImage
        }

        let url = URL(string: "\(supabaseURL)/functions/v1/analyze-clothing")!
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval

        // Build multipart body
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClothingAnalysisError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[ClothingAnalysis] HTTP \(httpResponse.statusCode): \(bodyStr)")
            if httpResponse.statusCode == 401 {
                throw SupabaseAIError.unauthorized
            }
            let message = parseErrorMessage(from: data)
            throw ClothingAnalysisError.requestFailed(message: message)
        }

        if let bodyStr = String(data: data, encoding: .utf8) {
            print("[ClothingAnalysis] Response: \(bodyStr)")
        }

        return try parseResponse(data)
    }

    // MARK: - Private

    private func parseResponse(_ data: Data) throws -> ClothingAnalysisResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClothingAnalysisError.invalidResponse
        }

        var result = ClothingAnalysisResult()

        // Category — case-insensitive match
        if let categoryStr = json["category"] as? String {
            result.category = ClothingCategory.allCases.first {
                $0.rawValue.caseInsensitiveCompare(categoryStr) == .orderedSame
            }
        }

        // Color
        if let colorStr = json["color"] as? String {
            result.color = ClothingColor.allCases.first {
                $0.rawValue.caseInsensitiveCompare(colorStr) == .orderedSame
            }
        }

        // Season
        if let seasonStr = json["season"] as? String {
            result.season = Season.allCases.first {
                $0.rawValue.caseInsensitiveCompare(seasonStr) == .orderedSame
            }
        }

        // Style
        if let styleStr = json["style"] as? String {
            result.style = Style.allCases.first {
                $0.rawValue.caseInsensitiveCompare(styleStr) == .orderedSame
            }
        }

        // Brand
        if let brandStr = json["brand"] as? String, !brandStr.isEmpty {
            result.brand = brandStr
        }

        // Name
        if let nameStr = json["name"] as? String, !nameStr.isEmpty {
            result.name = nameStr
        }

        // Material
        if let materialStr = json["material"] as? String, !materialStr.isEmpty {
            result.material = materialStr
        }

        // Size
        if let sizeStr = json["size"] as? String, !sizeStr.isEmpty {
            result.size = sizeStr
        }

        // Tags
        if let tagsArr = json["tags"] as? [String], !tagsArr.isEmpty {
            result.tags = tagsArr
        }

        return result
    }

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

enum ClothingAnalysisError: LocalizedError {
    case invalidImage
    case invalidResponse
    case requestFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image for analysis."
        case .invalidResponse:
            return "Received an invalid response from analysis service."
        case .requestFailed(let message):
            return message
        }
    }
}

// MARK: - Data Helper

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
