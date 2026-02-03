//
//  DesignSystem.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

// MARK: - App Design System

enum AppDesign {
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let xxlarge: CGFloat = 24
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let largeTitle: Font = .system(size: 34, weight: .bold, design: .rounded)
        static let title: Font = .system(size: 28, weight: .bold, design: .rounded)
        static let title2: Font = .system(size: 22, weight: .bold, design: .rounded)
        static let headline: Font = .system(size: 17, weight: .semibold, design: .rounded)
        static let body: Font = .system(size: 17, weight: .regular, design: .rounded)
        static let bodyBold: Font = .system(size: 17, weight: .bold, design: .rounded)
        static let callout: Font = .system(size: 16, weight: .regular, design: .rounded)
        static let subheadline: Font = .system(size: 15, weight: .regular, design: .rounded)
        static let footnote: Font = .system(size: 13, weight: .regular, design: .rounded)
        static let caption: Font = .system(size: 12, weight: .regular, design: .rounded)
        static let captionBold: Font = .system(size: 12, weight: .semibold, design: .rounded)
    }
    
    // MARK: - Colors
    
    enum Colors {
        static let primary: Color = .blue
        static let secondary: Color = .purple
        static let accent: Color = .pink
        static let success: Color = .green
        static let warning: Color = .orange
        static let error: Color = .red
        
        static var primaryGradient: LinearGradient {
            LinearGradient(
                colors: [primary, secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static var premiumGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: "f39c12"), Color(hex: "e67e22")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static func cardBackground(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
        }
        
        static func textPrimary(_ colorScheme: ColorScheme) -> Color {
            Color(.label)
        }
        
        static func textSecondary(_ colorScheme: ColorScheme) -> Color {
            Color(.secondaryLabel)
        }
    }
    
    // MARK: - Shadow
    
    enum Shadow {
        static func card(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark 
                ? Color.black.opacity(0.3)
                : Color.black.opacity(0.1)
        }
        
        static func button(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.black.opacity(0.4)
                : Color.black.opacity(0.2)
        }
    }
}

// MARK: - Button Styles

struct PremiumButtonStyle: ButtonStyle {
    var gradient: LinearGradient?
    var isLoading: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppDesign.Spacing.m)
            .background(
                ZStack {
                    if let gradient = gradient {
                        gradient
                    } else {
                        LinearGradient(
                            colors: [AppDesign.Colors.primary, AppDesign.Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .foregroundColor(.white)
            .cornerRadius(AppDesign.CornerRadius.large)
            .shadow(
                color: AppDesign.Shadow.button(.light).opacity(0.5),
                radius: 12,
                x: 0,
                y: 6
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(isLoading ? 0.6 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppDesign.Spacing.m)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
            .cornerRadius(AppDesign.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.large)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Card Style

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(AppDesign.Spacing.m)
            .background(AppDesign.Colors.cardBackground(colorScheme))
            .cornerRadius(AppDesign.CornerRadius.large)
            .shadow(
                color: AppDesign.Shadow.card(colorScheme),
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

