import SwiftUI

enum VFont {
    // MARK: - Size scale
    static let scoreHero:   CGFloat = 72
    static let scoreLarge:  CGFloat = 52
    static let titleLarge:  CGFloat = 34
    static let titleMedium: CGFloat = 24
    static let titleSmall:  CGFloat = 20
    static let bodyLarge:   CGFloat = 17
    static let bodyMedium:  CGFloat = 15
    static let bodySmall:   CGFloat = 13
    static let caption:     CGFloat = 11

    // MARK: - Semantic fonts
    static var scoreHeroFont:   Font { .system(size: scoreHero, weight: .black, design: .rounded) }
    static var scoreLargeFont:  Font { .system(size: scoreLarge, weight: .black, design: .rounded) }
    static var titleLargeFont:  Font { .system(size: titleLarge, weight: .bold) }
    static var titleMediumFont: Font { .system(size: titleMedium, weight: .semibold) }
    static var titleSmallFont:  Font { .system(size: titleSmall, weight: .semibold) }
    static var bodyLargeFont:   Font { .system(size: bodyLarge, weight: .regular) }
    static var bodyMediumFont:  Font { .system(size: bodyMedium, weight: .regular) }
    static var bodySmallFont:   Font { .system(size: bodySmall, weight: .regular) }
    static var captionFont:     Font { .system(size: caption, weight: .regular) }
    static var tierBadgeFont:   Font { .system(size: 10, weight: .semibold, design: .monospaced) }
    static var metricValueFont: Font { .system(size: titleSmall, weight: .bold, design: .rounded) }
    static var metricUnitFont:  Font { .system(size: bodySmall, weight: .medium) }
}
