import SwiftUI

struct RePlanNudgeBanner: View {
    var onGeneratePlan: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: VSpacing.m) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VColor.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Your metrics have shifted")
                    .font(.system(size: VFont.bodySmall, weight: .semibold))
                    .foregroundStyle(VColor.textPrimary)
                Text("Consider generating an updated plan.")
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textSecondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VColor.textTertiary)
            }
        }
        .padding(VSpacing.m)
        .background(VColor.accentFaint)
        .clipShape(RoundedRectangle(cornerRadius: VRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: VRadius.large)
                .strokeBorder(VColor.accent.opacity(0.3), lineWidth: 1)
        )
    }
}
