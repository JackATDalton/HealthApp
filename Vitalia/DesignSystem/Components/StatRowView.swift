import SwiftUI

struct StatRowView: View {
    let label: String
    let value: String
    var valueColor: Color = VColor.textPrimary
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(VFont.bodySmallFont)
                    .foregroundStyle(VColor.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: VFont.bodySmall, weight: .semibold, design: .rounded))
                    .foregroundStyle(valueColor)
            }
            .padding(.vertical, VSpacing.m)

            if showDivider {
                Rectangle()
                    .fill(VColor.borderSubtle)
                    .frame(height: 0.5)
            }
        }
    }
}
