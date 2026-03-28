import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

enum VColor {
    // MARK: - Backgrounds
    static let backgroundPrimary    = Color(hex: "#0A0A0A")
    static let backgroundSecondary  = Color(hex: "#111111")
    static let backgroundTertiary   = Color(hex: "#1A1A1A")
    static let backgroundQuarternary = Color(hex: "#222222")

    // MARK: - Accent (warm amber-terracotta)
    static let accent               = Color(hex: "#E8854A")
    static let accentSubdued        = Color(hex: "#8A4E2C")
    static let accentFaint          = Color(hex: "#2A1A10")

    // MARK: - Semantic (metric status)
    static let optimal              = Color(hex: "#4CAF7A")
    static let optimalFaint         = Color(hex: "#0D2B1A")
    static let borderline           = Color(hex: "#E8B84A")
    static let borderlineFaint      = Color(hex: "#2B220A")
    static let outOfRange           = Color(hex: "#E05252")
    static let outOfRangeFaint      = Color(hex: "#2B0D0D")
    static let disabled             = Color(hex: "#3A3A3A")

    // MARK: - Recovery bands
    static let recoveryGreen        = Color(hex: "#4CAF7A")
    static let recoveryAmber        = Color(hex: "#E8B84A")
    static let recoveryOrange       = Color(hex: "#E87A3A")
    static let recoveryRed          = Color(hex: "#E05252")

    // MARK: - Text
    static let textPrimary          = Color(hex: "#F5F0EB")
    static let textSecondary        = Color(hex: "#9A9490")
    static let textTertiary         = Color(hex: "#5A5652")
    static let textInverse          = Color(hex: "#0A0A0A")

    // MARK: - Borders
    static let borderSubtle         = Color(hex: "#1E1E1E")
    static let borderMedium         = Color(hex: "#2E2E2E")
}
