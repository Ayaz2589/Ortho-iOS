import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @State private var showingAddCard = false

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel("Household")

                    VStack(spacing: 0) {
                        householdLinkRow
                    }
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    sectionLabel("Cards")

                    VStack(spacing: 0) {
                        ForEach(appState.cards) { c in
                            CardRowView(card: c) {
                                appState.deleteCard(c)
                            }
                            RowSeparator(density: .comfortable)
                        }
                        AddCardRowView { showingAddCard = true }
                    }
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    Text("Cards appear in the Paid with menu when you log a new expense. Existing transactions keep their original card name.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    sectionLabel("Currency")

                    VStack(spacing: 0) {
                        currencyRow
                    }
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    Text(ratesCaption)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    sectionLabel("Appearance")

                    VStack(spacing: 0) {
                        ForEach(Array(AppearanceMode.allCases.enumerated()), id: \.element.id) { idx, mode in
                            AppearanceRowView(
                                mode: mode,
                                selected: appearance == mode,
                                onTap: { appearanceRaw = mode.rawValue }
                            )
                            if idx < AppearanceMode.allCases.count - 1 {
                                RowSeparator(density: .comfortable)
                            }
                        }
                    }
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Bottom breathing room so the tab bar doesn't clip the
                    // last row. The NavigationStack toolbar-hidden chrome
                    // interferes with safe-area-inset propagation from
                    // RootTabView's tab bar, so we add the spacer explicitly.
                    Color.clear.frame(height: 60)
                }
            }
            .background(AppTheme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .background(AppTheme.bg)
            }
            .sheet(isPresented: $showingAddCard) {
                AddCardSheet { newCard in
                    appState.addCard(newCard)
                    showingAddCard = false
                }
                .presentationDetents([.large])
                .presentationBackground(AppTheme.bg)
            }
        }
    }

    // MARK: - Rows

    /// Single tappable row that pushes `HouseholdView` for full management.
    /// The right side shows the active household's name as a peek.
    private var householdLinkRow: some View {
        NavigationLink {
            HouseholdView()
                .environment(appState)
        } label: {
            HStack(spacing: 12) {
                Text("Household")
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                HStack(spacing: 6) {
                    Text(appState.currentHousehold?.name ?? "Untitled")
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.text2)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var currencyRow: some View {
        Menu {
            ForEach(Currency.allCases) { c in
                Button {
                    appState.currency = c
                } label: {
                    if c == appState.currency {
                        Label("\(c.displayName) (\(c.code))", systemImage: "checkmark")
                    } else {
                        Text("\(c.displayName) (\(c.code))")
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text("Currency")
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                HStack(spacing: 6) {
                    Text(appState.currency.displayName)
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.text2)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .kerning(0.6)
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.text.opacity(0.58))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }

    private var ratesCaption: String {
        if appState.ratesIsLoading && appState.fxRates.isEmpty {
            return "Updating rates…"
        }
        if let last = appState.ratesLastFetched {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            return "Rates updated \(f.localizedString(for: last, relativeTo: Date()))"
        }
        if appState.ratesError != nil {
            return "Rates unavailable; using approximate values."
        }
        return "Loading rates…"
    }
}

#Preview("Settings · Light") {
    SettingsView()
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Settings · Dark") {
    SettingsView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
