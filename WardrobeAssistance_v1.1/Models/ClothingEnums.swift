//
//  ClothingEnums.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI
import Foundation

// MARK: - Clothing Category
enum ClothingCategory: String, CaseIterable, Codable {
    case tops = "Tops"
    case bottoms = "Bottoms"
    case shoes = "Shoes"
    case accessories = "Accessories"
    case outerwear = "Outerwear"
    case dresses = "Dresses"
    case activewear = "Activewear"
    
    var icon: String {
        switch self {
        case .tops: return "tshirt.fill"
        case .bottoms: return "figure.walk"
        case .shoes: return "shoe.2.fill"
        case .accessories: return "bag.fill"
        case .outerwear: return "jacket"
        case .dresses: return "figure.dress.line.vertical.figure"
        case .activewear: return "figure.run"
        }
    }
}

// MARK: - Season
enum Season: String, CaseIterable, Codable {
    case summer = "Summer"
    case winter = "Winter"
    case spring = "Spring"
    case fall = "Fall"
    case allSeason = "All Season"
}

// MARK: - Style
enum Style: String, CaseIterable, Codable {
    case casual = "Casual"
    case formal = "Formal"
    case sportswear = "Sportswear"
    case business = "Business"
    case evening = "Evening"
    case streetwear = "Streetwear"
}

// MARK: - Color
enum ClothingColor: String, CaseIterable, Codable {
    case black = "Black"
    case white = "White"
    case gray = "Gray"
    case navy = "Navy"
    case blue = "Blue"
    case red = "Red"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case purple = "Purple"
    case pink = "Pink"
    case brown = "Brown"
    case beige = "Beige"
    case multicolor = "Multicolor"
    
    var color: Color {
        switch self {
        case .black: return .black
        case .white: return .white
        case .gray: return .gray
        case .navy: return .blue
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .beige: return Color(red: 0.96, green: 0.96, blue: 0.86)
        case .multicolor: return .blue
        }
    }
}

// MARK: - Occasion
enum Occasion: String, CaseIterable, Codable {
    case work = "Work"
    case casual = "Casual"
    case date = "Date"
    case sports = "Sports"
    case party = "Party"
    case formal = "Formal"
    case travel = "Travel"
    case home = "Home"
}

