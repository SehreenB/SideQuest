import SwiftUI

enum Theme {
    static let terracotta = Color(hex: "#C26D4A")
    static let sage       = Color(hex: "#7A9B8E")
    static let bg         = Color(hex: "#FAF7F2")
    static let text       = Color(hex: "#4A352D")
    static let gold       = Color(hex: "#D4A373")
}

enum ThemeFont {
    static let heroTitle = Font.system(size: 54, weight: .bold, design: .serif)
    static let quote = Font.system(size: 24, weight: .semibold, design: .serif)
    static let pageTitle = Font.system(size: 32, weight: .bold, design: .serif)
    static let sectionTitle = Font.system(size: 22, weight: .bold, design: .serif)
    static let titleMedium = Font.system(size: 28, weight: .bold, design: .serif)
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let bodyStrong = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let bodySmall = Font.system(size: 14, weight: .medium, design: .rounded)
    static let bodySmallStrong = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
    static let micro = Font.system(size: 11, weight: .medium, design: .rounded)
    static let button = Font.system(size: 18, weight: .bold, design: .rounded)
    static let buttonSmall = Font.system(size: 16, weight: .bold, design: .rounded)
    static let cardValue = Font.system(size: 20, weight: .bold, design: .rounded)
    static let metric = Font.system(size: 34, weight: .heavy, design: .rounded)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8: (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
