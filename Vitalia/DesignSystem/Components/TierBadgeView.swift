import SwiftUI

struct TierBadgeView: View {
    let tier: Int
    var isEnabled: Bool = true

    private var label: String { "T\(tier)" }

    var body: some View {
        Text(label)
            .font(VFont.tierBadgeFont)
            .foregroundStyle(isEnabled ? foregroundColor : VColor.textTertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isEnabled ? background : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isEnabled ? borderColor : VColor.borderMedium, lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        switch tier {
        case 1:  VColor.textInverse
        default: VColor.textSecondary
        }
    }

    private var background: Color {
        switch tier {
        case 1:  VColor.accent
        default: Color.clear
        }
    }

    private var borderColor: Color {
        switch tier {
        case 1:  VColor.accent
        case 2:  VColor.accentSubdued
        default: VColor.borderMedium
        }
    }
}
