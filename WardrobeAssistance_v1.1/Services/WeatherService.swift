//
//  WeatherService.swift
//  WardrobeAssistance_v1.1
//
//  Created by AI Assistant
//

import Foundation
import CoreLocation

/// Weather service using Open-Meteo free API
final class WeatherService: NSObject, ObservableObject {
    static let shared = WeatherService()

    @Published var currentWeather: WeatherData?
    @Published var locationError: Error?

    private let locationManager = CLLocationManager()
    private var cachedWeather: (data: WeatherData, timestamp: Date)?
    private let cacheTimeout: TimeInterval = 30 * 60 // 30 minutes

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public Methods

    /// Fetches current weather data
    func fetchWeather() async throws -> WeatherData {
        // Check cache first
        if let cached = cachedWeather,
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return cached.data
        }

        // Try to get location-based weather
        if let location = await requestLocation() {
            do {
                let weather = try await fetchWeatherForLocation(location)
                cacheWeather(weather)
                await MainActor.run {
                    self.currentWeather = weather
                }
                return weather
            } catch {
                print("⚠️ Failed to fetch weather: \(error), using fallback")
            }
        }

        // Fallback to default weather
        let fallback = createFallbackWeather()
        await MainActor.run {
            self.currentWeather = fallback
        }
        return fallback
    }

    // MARK: - Private Methods

    private func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let status = self.locationManager.authorizationStatus

                switch status {
                case .notDetermined:
                    self.locationCompletion = continuation
                    self.locationManager.requestWhenInUseAuthorization()
                case .authorizedWhenInUse, .authorizedAlways:
                    self.locationCompletion = continuation
                    self.locationManager.requestLocation()
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private var locationCompletion: CheckedContinuation<CLLocation?, Never>?

    private func fetchWeatherForLocation(_ location: CLLocation) async throws -> WeatherData {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Open-Meteo API (free, no key required)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&timezone=auto"

        guard let url = URL(string: urlString) else {
            throw AIError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        let decoder = JSONDecoder()
        let weatherResponse = try decoder.decode(OpenMeteoResponse.self, from: data)

        return WeatherData(
            temperature: weatherResponse.current.temperature_2m,
            condition: mapWeatherCode(weatherResponse.current.weather_code),
            humidity: weatherResponse.current.relative_humidity_2m,
            windSpeed: weatherResponse.current.wind_speed_10m
        )
    }

    private func mapWeatherCode(_ code: Int) -> WeatherCondition {
        // Open-Meteo weather codes
        switch code {
        case 0: return .sunny
        case 1...3: return .cloudy
        case 45, 48: return .foggy
        case 51...67, 80...82: return .rainy
        case 71...77, 85...86: return .snowy
        default: return .sunny
        }
    }

    private func createFallbackWeather() -> WeatherData {
        // Default pleasant weather
        return WeatherData(
            temperature: 20.0,
            condition: .sunny,
            humidity: 50.0,
            windSpeed: 5.0
        )
    }

    private func cacheWeather(_ weather: WeatherData) {
        cachedWeather = (weather, Date())
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            locationCompletion?.resume(returning: location)
            locationCompletion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationCompletion?.resume(returning: nil)
        locationCompletion = nil

        Task { @MainActor in
            self.locationError = error
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            locationCompletion?.resume(returning: nil)
            locationCompletion = nil
        }
    }
}

// MARK: - Open-Meteo Response Models

private struct OpenMeteoResponse: Codable {
    let current: CurrentWeather

    struct CurrentWeather: Codable {
        let temperature_2m: Double
        let relative_humidity_2m: Double
        let wind_speed_10m: Double
        let weather_code: Int
    }
}
