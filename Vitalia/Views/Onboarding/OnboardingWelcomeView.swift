import SwiftUI

struct OnboardingWelcomeView: View {
    let onAuthorised: () -> Void
    @State private var requesting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo area
            VStack(spacing: VSpacing.l) {
                ZStack {
                    Circle()
                        .fill(VColor.accentFaint)
                        .frame(width: 100, height: 100)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(VColor.accent)
                }

                VStack(spacing: VSpacing.s) {
                    Text("Vitalia")
                        .font(VFont.titleLargeFont)
                        .foregroundStyle(VColor.textPrimary)

                    Text("Your personal longevity coach.")
                        .font(VFont.bodyLargeFont)
                        .foregroundStyle(VColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            // Features list
            VStack(alignment: .leading, spacing: VSpacing.l) {
                featureRow(icon: "bolt.heart.fill",       title: "Daily Recovery Score",
                           detail: "Built from HRV, sleep quality, SpO₂ and more.")
                featureRow(icon: "figure.run.circle.fill", title: "Longevity Score",
                           detail: "Evidence-weighted across all your health metrics.")
                featureRow(icon: "brain.head.profile",    title: "Claude-Powered Plans",
                           detail: "Personalised, on-demand analysis of your real data.")
                featureRow(icon: "lock.shield.fill",      title: "Fully Private",
                           detail: "Everything stays on your device. No accounts.")
            }
            .padding(.horizontal, VSpacing.xl)

            Spacer()

            // CTA
            VStack(spacing: VSpacing.m) {
                if let error {
                    Text(error)
                        .font(VFont.captionFont)
                        .foregroundStyle(VColor.outOfRange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VSpacing.xl)
                }

                Button {
                    Task { await requestAccess() }
                } label: {
                    HStack(spacing: VSpacing.s) {
                        if requesting {
                            ProgressView()
                                .tint(VColor.textInverse)
                                .scaleEffect(0.85)
                        }
                        Text(requesting ? "Requesting Access…" : "Connect Apple Health")
                            .font(.system(size: VFont.bodyLarge, weight: .semibold))
                    }
                    .foregroundStyle(VColor.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VSpacing.l)
                    .background(requesting ? VColor.accentSubdued : VColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
                }
                .disabled(requesting)
                .padding(.horizontal, VSpacing.l)

                Text("Vitalia only reads data — it never writes to Apple Health.")
                    .font(VFont.captionFont)
                    .foregroundStyle(VColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.xl)
            }
            .padding(.bottom, VSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColor.backgroundPrimary.ignoresSafeArea())
    }

    private func requestAccess() async {
        requesting = true
        error = nil
        do {
            let manager = HealthKitPermissionsManager()
            guard manager.isAvailable else {
                error = "Apple Health is not available on this device."
                requesting = false
                return
            }
            try await manager.requestAuthorization()
            onAuthorised()
        } catch {
            self.error = "Could not connect to Apple Health. Please try again."
            requesting = false
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: VSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(VColor.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: VFont.bodyMedium, weight: .semibold))
                    .foregroundStyle(VColor.textPrimary)
                Text(detail)
                    .font(VFont.bodySmallFont)
                    .foregroundStyle(VColor.textSecondary)
            }
        }
    }
}
