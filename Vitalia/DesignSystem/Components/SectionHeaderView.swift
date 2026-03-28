import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text(title)
                    .font(VFont.titleSmallFont)
                    .foregroundStyle(VColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                }
            }
            Spacer()
        }
    }
}
