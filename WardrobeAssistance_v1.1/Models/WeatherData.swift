//
//  WeatherData.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import Foundation

// MARK: - Weather Condition
enum WeatherCondition: String, Codable {
    case sunny = "Sunny"
    case cloudy = "Cloudy"
    case rainy = "Rainy"
    case snowy = "Snowy"
    case windy = "Windy"
    case foggy = "Foggy"
}

// MARK: - Weather Data Model
struct WeatherData: Codable {
    var temperature: Double // Celsius
    var condition: WeatherCondition
    var humidity: Double
    var windSpeed: Double
    
    var temperatureFahrenheit: Double {
        return (temperature * 9/5) + 32
    }
    
    var isCold: Bool {
        return temperature < 15
    }
    
    var isHot: Bool {
        return temperature > 25
    }
    
    var recommendedSeason: Season {
        if temperature < 5 {
            return .winter
        } else if temperature < 15 {
            return .fall
        } else if temperature < 25 {
            return .spring
        } else {
            return .summer
        }
    }
}

