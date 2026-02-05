//
//  AuthService.swift
//  WardrobeAssistance_v1.1
//
//  Supabase Anonymous Authentication Service
//

import Foundation
import Security

/// Service for managing anonymous authentication with Supabase
final class AuthService {
    static let shared = AuthService()

    // MARK: - Configuration

    private let supabaseURL = "https://lqpmgnfjwlecgxecuqtg.supabase.co"
    private let supabaseAnonKey = "sb_publishable_EhqOZ7d8Vx736dCq9vmRMQ_iy2SlnEH"

    // MARK: - Keychain Keys

    private let accessTokenKey = "com.wardrobeassistant.supabase.accessToken"
    private let refreshTokenKey = "com.wardrobeassistant.supabase.refreshToken"
    private let expiresAtKey = "com.wardrobeassistant.supabase.expiresAt"
    private let userIdKey = "com.wardrobeassistant.supabase.userId"

    // MARK: - State

    private var cachedAccessToken: String?
    private var cachedExpiresAt: Date?
    private var cachedUserId: String?
    private let tokenActor = TokenActor()

    private init() {
        loadCachedCredentials()
    }

    // MARK: - Public Methods

    /// Returns a valid access token, refreshing if necessary
    /// On first launch, performs anonymous sign-up
    func getValidToken() async throws -> String {
        // Check if we have a valid cached token
        if let token = cachedAccessToken,
           let expiresAt = cachedExpiresAt,
           expiresAt > Date().addingTimeInterval(60) {
            return token
        }

        // Use actor to prevent concurrent token refreshes
        return try await tokenActor.getOrRefreshToken { [self] in
            // Try to refresh existing token
            if let refreshToken = getKeychainValue(for: refreshTokenKey) {
                do {
                    let tokens = try await refreshAccessToken(refreshToken: refreshToken)
                    await saveTokens(tokens)
                    return tokens.accessToken
                } catch {
                    print("Token refresh failed: \(error)")
                }
            }

            // No valid token, perform anonymous sign-up
            let tokens = try await signUpAnonymously()
            await saveTokens(tokens)
            return tokens.accessToken
        }
    }

    /// Returns the current user ID if authenticated
    var currentUserId: String? {
        return cachedUserId ?? getKeychainValue(for: userIdKey)
    }

    /// Clears all stored credentials (for sign-out or reset)
    func clearCredentials() {
        deleteKeychainValue(for: accessTokenKey)
        deleteKeychainValue(for: refreshTokenKey)
        deleteKeychainValue(for: expiresAtKey)
        deleteKeychainValue(for: userIdKey)
        cachedAccessToken = nil
        cachedExpiresAt = nil
        cachedUserId = nil
    }

    // MARK: - Private Methods

    private func signUpAnonymously() async throws -> AuthTokens {
        let url = URL(string: "\(supabaseURL)/auth/v1/signup")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        // Empty body for anonymous sign-up
        let body: [String: Any] = [:]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            return try parseAuthResponse(data: data)
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.signUpFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
    }

    private func refreshAccessToken(refreshToken: String) async throws -> AuthTokens {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return try parseAuthResponse(data: data)
        } else {
            throw AuthError.refreshFailed(statusCode: httpResponse.statusCode)
        }
    }

    private func parseAuthResponse(data: Data) throws -> AuthTokens {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let authResponse = try decoder.decode(SupabaseAuthResponse.self, from: data)

        guard let accessToken = authResponse.accessToken,
              let refreshToken = authResponse.refreshToken,
              let expiresIn = authResponse.expiresIn else {
            throw AuthError.invalidResponse
        }

        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

        return AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            userId: authResponse.user?.id
        )
    }

    private func saveTokens(_ tokens: AuthTokens) async {
        // Save to Keychain
        setKeychainValue(tokens.accessToken, for: accessTokenKey)
        setKeychainValue(tokens.refreshToken, for: refreshTokenKey)
        setKeychainValue(String(tokens.expiresAt.timeIntervalSince1970), for: expiresAtKey)
        if let userId = tokens.userId {
            setKeychainValue(userId, for: userIdKey)
        }

        // Update cache
        cachedAccessToken = tokens.accessToken
        cachedExpiresAt = tokens.expiresAt
        cachedUserId = tokens.userId
    }

    private func loadCachedCredentials() {
        cachedAccessToken = getKeychainValue(for: accessTokenKey)
        cachedUserId = getKeychainValue(for: userIdKey)

        if let expiresAtString = getKeychainValue(for: expiresAtKey),
           let expiresAtInterval = Double(expiresAtString) {
            cachedExpiresAt = Date(timeIntervalSince1970: expiresAtInterval)
        }
    }

    // MARK: - Keychain Helpers

    private func setKeychainValue(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!

        // Delete query (without kSecValueData)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        // Delete any existing item
        SecItemDelete(deleteQuery as CFDictionary)

        // Add query (with kSecValueData)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Add new item
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain write failed for \(key): \(status)")
        }
    }

    private func getKeychainValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteKeychainValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Models

struct AuthTokens {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: String?
}

struct SupabaseAuthResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let user: SupabaseUser?
}

struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let role: String?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidResponse
    case signUpFailed(statusCode: Int, message: String)
    case refreshFailed(statusCode: Int)
    case noCredentials
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid authentication response"
        case .signUpFailed(let code, let message):
            return "Sign up failed (\(code)): \(message)"
        case .refreshFailed(let code):
            return "Token refresh failed with status \(code)"
        case .noCredentials:
            return "No stored credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Token Actor for Thread Safety

private actor TokenActor {
    private var inProgressTask: Task<String, Error>?

    func getOrRefreshToken(_ refreshAction: @escaping () async throws -> String) async throws -> String {
        // If there's already a refresh in progress, wait for it
        if let existingTask = inProgressTask {
            return try await existingTask.value
        }

        // Start a new refresh task
        let task = Task<String, Error> {
            try await refreshAction()
        }

        inProgressTask = task

        do {
            let result = try await task.value
            inProgressTask = nil
            return result
        } catch {
            inProgressTask = nil
            throw error
        }
    }
}
