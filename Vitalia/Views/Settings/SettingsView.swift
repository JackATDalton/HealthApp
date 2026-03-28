import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var showAPIKeyEntry = false
    @State private var selectedModel = "claude-sonnet-4-6"
    @State private var usesMetric = true

    private let models = ["claude-sonnet-4-6", "claude-opus-4-6"]

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section {
                    if let profile = profiles.first {
                        profileRow(profile: profile)
                    } else {
                        Button("Set up profile") {}
                            .foregroundStyle(VColor.accent)
                    }
                } header: {
                    sectionHeader("Profile")
                }
                .listRowBackground(VColor.backgroundSecondary)

                // Claude section
                Section {
                    apiKeyRow
                    modelPickerRow
                } header: {
                    sectionHeader("Claude API")
                }
                .listRowBackground(VColor.backgroundSecondary)

                // Preferences
                Section {
                    Toggle(isOn: $usesMetric) {
                        label("Units", systemImage: "ruler", value: usesMetric ? "Metric" : "Imperial")
                    }
                    .tint(VColor.accent)
                } header: {
                    sectionHeader("Preferences")
                }
                .listRowBackground(VColor.backgroundSecondary)

                // Privacy
                Section {
                    NavigationLink {
                        PrivacyInfoView()
                    } label: {
                        label("Data & Privacy", systemImage: "lock.shield", value: "On-device only")
                    }
                } header: {
                    sectionHeader("Privacy")
                }
                .listRowBackground(VColor.backgroundSecondary)

                // About
                Section {
                    label("Version", systemImage: "info.circle", value: "1.0")
                } header: {
                    sectionHeader("About")
                }
                .listRowBackground(VColor.backgroundSecondary)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VColor.backgroundPrimary)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func profileRow(profile: UserProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(profileSummary(profile))
                    .font(VFont.bodyMediumFont)
                    .foregroundStyle(VColor.textPrimary)
                Text(profile.fitnessBackground.rawValue)
                    .font(VFont.bodySmallFont)
                    .foregroundStyle(VColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VColor.textTertiary)
        }
    }

    private func profileSummary(_ profile: UserProfile) -> String {
        var parts: [String] = []
        if let age = profile.ageYears { parts.append("\(age) yrs") }
        if profile.biologicalSex != "unknown" { parts.append(profile.biologicalSex.capitalized) }
        if let height = profile.heightCm { parts.append(String(format: "%.0f cm", height)) }
        return parts.isEmpty ? "Tap to complete profile" : parts.joined(separator: " · ")
    }

    private var apiKeyRow: some View {
        Button {
            showAPIKeyEntry = true
        } label: {
            label("API Key", systemImage: "key.fill", value: "Stored in Keychain")
        }
        .sheet(isPresented: $showAPIKeyEntry) {
            APIKeyView()
        }
    }

    private var modelPickerRow: some View {
        HStack {
            Image(systemName: "brain")
                .foregroundStyle(VColor.accent)
                .frame(width: 20)
            Text("Model")
                .font(VFont.bodyMediumFont)
                .foregroundStyle(VColor.textPrimary)
            Spacer()
            Picker("", selection: $selectedModel) {
                ForEach(models, id: \.self) { model in
                    Text(model.replacingOccurrences(of: "claude-", with: ""))
                        .tag(model)
                }
            }
            .pickerStyle(.menu)
            .tint(VColor.accent)
        }
    }

    private func label(_ title: String, systemImage: String, value: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(VColor.accent)
                .frame(width: 20)
            Text(title)
                .font(VFont.bodyMediumFont)
                .foregroundStyle(VColor.textPrimary)
            Spacer()
            Text(value)
                .font(VFont.bodySmallFont)
                .foregroundStyle(VColor.textTertiary)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VFont.captionFont)
            .foregroundStyle(VColor.textTertiary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

// MARK: - API Key view

struct APIKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var keyText = ""
    @State private var isRevealed = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VSpacing.xl) {
                VStack(alignment: .leading, spacing: VSpacing.s) {
                    Text("Your Claude API key is stored securely in the iOS Keychain and never leaves your device.")
                        .font(VFont.bodyMediumFont)
                        .foregroundStyle(VColor.textSecondary)
                }

                HStack {
                    Group {
                        if isRevealed {
                            TextField("sk-ant-...", text: $keyText)
                        } else {
                            SecureField("sk-ant-...", text: $keyText)
                        }
                    }
                    .font(.system(size: VFont.bodyMedium, design: .monospaced))
                    .foregroundStyle(VColor.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .foregroundStyle(VColor.textTertiary)
                    }
                }
                .padding(VSpacing.l)
                .background(VColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: VRadius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: VRadius.large)
                        .strokeBorder(VColor.borderMedium, lineWidth: 1)
                )

                Button {
                    // Phase 4: save to Keychain
                    dismiss()
                } label: {
                    Text("Save Key")
                        .font(.system(size: VFont.bodyLarge, weight: .semibold))
                        .foregroundStyle(VColor.textInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VSpacing.l)
                        .background(keyText.isEmpty ? VColor.disabled : VColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: VRadius.xl))
                }
                .disabled(keyText.isEmpty)

                Spacer()
            }
            .padding(VSpacing.l)
            .background(VColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(VColor.accent)
                }
            }
        }
        .presentationBackground(VColor.backgroundPrimary)
        .presentationDetents([.medium])
    }
}

// MARK: - Privacy info view

private struct PrivacyInfoView: View {
    var body: some View {
        List {
            Section {
                infoRow(icon: "iphone", title: "All data stays on your device", body: "Health data is never sent to any server except the Claude API.")
                infoRow(icon: "doc.text.magnifyingglass", title: "Only summaries sent to Claude", body: "Raw time-series data is never shared — only structured metric snapshots.")
                infoRow(icon: "key.fill", title: "API key in Keychain", body: "Your Anthropic API key is stored in the iOS Keychain, not in app storage or logs.")
                infoRow(icon: "eye.slash", title: "No analytics", body: "No crash reporters, no telemetry, no third-party SDKs.")
            }
            .listRowBackground(VColor.backgroundSecondary)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VColor.backgroundPrimary)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(VColor.backgroundPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func infoRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: VSpacing.m) {
            Image(systemName: icon)
                .foregroundStyle(VColor.accent)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text(title)
                    .font(.system(size: VFont.bodyMedium, weight: .semibold))
                    .foregroundStyle(VColor.textPrimary)
                Text(body)
                    .font(VFont.bodySmallFont)
                    .foregroundStyle(VColor.textSecondary)
            }
        }
        .padding(.vertical, VSpacing.xs)
    }
}
