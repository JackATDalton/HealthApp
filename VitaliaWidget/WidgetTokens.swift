import SwiftUI

// Local design tokens for the widget — mirrors the main app's VColor/VSpacing values.

extension Color {
    init(widgetHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

enum WColor {
    static let backgroundPrimary  = Color(widgetHex: "#0A0A0A")
    static let backgroundSecondary = Color(widgetHex: "#111111")
    static let accent             = Color(widgetHex: "#E8854A")
    static let excellent          = Color(widgetHex: "#2D8653")
    static let optimal            = Color(widgetHex: "#4CAF7A")
    static let borderline         = Color(widgetHex: "#E8B84A")
    static let outOfRange         = Color(widgetHex: "#E05252")
    static let textPrimary        = Color(widgetHex: "#F5F0EB")
    static let textSecondary      = Color(widgetHex: "#9A9490")
    static let textTertiary       = Color(widgetHex: "#5A5652")

    static func forScore(_ score: Double) -> Color {
        if score >= 90 { return excellent }
        if score >= 75 { return optimal }
        if score >= 50 { return borderline }
        return outOfRange
    }

    static func labelForScore(_ score: Double) -> String {
        if score >= 90 { return "Excellent" }
        if score >= 75 { return "Good" }
        if score >= 50 { return "Borderline" }
        return "Out of Range"
    }
}

enum WSpacing {
    static let xs: CGFloat = 4
    static let s:  CGFloat = 8
    static let m:  CGFloat = 12
    static let l:  CGFloat = 16
}
