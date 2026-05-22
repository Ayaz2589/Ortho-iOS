import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @AppStorage("language") private var languageRaw: String = AppLanguage.system.rawValue
    @State private var showingAddCard = false
    @State private var showingSignOutConfirm = false
    #if DEBUG
    @State private var showingLoadDummyConfirm = false
    #endif

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
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

                    sectionLabel("Budgets")

                    VStack(spacing: 0) {
                        budgetsLinkRow
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
                        .font(.lato(size: 13))
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
                        .font(.lato(size: 13))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    sectionLabel("Language")

                    VStack(spacing: 0) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { idx, lang in
                            LanguageRowView(
                                language: lang,
                                selected: language == lang,
                                onTap: { languageRaw = lang.rawValue }
                            )
                            if idx < AppLanguage.allCases.count - 1 {
                                RowSeparator(density: .comfortable)
                            }
                        }
                    }
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
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

                    sectionLabel("Account")

                    VStack(spacing: 0) {
                        signOutRow
                    }
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    #if DEBUG
                    sectionLabel("Developer")

                    VStack(spacing: 0) {
                        loadDummyDataRow
                        RowSeparator(density: .comfortable)
                        syncFromServerRow
                    }
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    Text("Only visible in DEBUG builds. \"Load demo data\" enters demo mode — the app shows a 6-month sample dataset, and every change you make stays local (nothing syncs to Supabase). A banner appears at the top with an Exit button that restores your real data. \"Sync all from server\" replaces local transactions, cards, properties, and rental payments with what Supabase returns.")
                        .font(.lato(size: 13))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    #endif

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
                        .font(.lato(size: 32, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 5)
                .background(colorScheme == .dark ? AnyShapeStyle(AppTheme.bg) : AnyShapeStyle(.regularMaterial))
            }
            .sheet(isPresented: $showingAddCard) {
                AddCardSheet { newCard in
                    appState.addCard(newCard)
                    showingAddCard = false
                }
                .presentationDetents([.large])
                .presentationBackground(AppTheme.bg)
            }
            .alert("Sign out of Ortho?", isPresented: $showingSignOutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Sign out", role: .destructive) {
                    Task { await appState.signOut() }
                }
            } message: {
                Text("You'll need to sign in again next time you open Ortho.")
            }
            #if DEBUG
            .alert("Enter demo mode?",
                   isPresented: $showingLoadDummyConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Load demo") {
                    appState.loadDummyData()
                }
            } message: {
                Text("The app will show a 6-month sample dataset (3 users · 3 properties · ~300 transactions). Your real data on Supabase isn't touched, and changes you make in demo mode stay local. Tap Exit in the banner at the top to restore your live data.")
            }
            #endif
        }
    }

    #if DEBUG
    private var loadDummyDataRow: some View {
        Button {
            showingLoadDummyConfirm = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.text.opacity(0.05))
                        .frame(width: 40, height: 40)
                    Image(systemName: "tray.and.arrow.down")
                        .font(.lato(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Load demo data")
                        .font(.lato(size: 17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.text)
                    Text("6 months · 3 users · 3 properties")
                        .font(.lato(size: 13))
                        .foregroundStyle(AppTheme.text.opacity(0.58))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.lato(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text.opacity(0.36))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var syncFromServerRow: some View {
        Button {
            Task { await appState.loadAllFromServer() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.text.opacity(0.05))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.lato(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sync all from server")
                        .font(.lato(size: 17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.text)
                    Text("Replace local data with Supabase")
                        .font(.lato(size: 13))
                        .foregroundStyle(AppTheme.text.opacity(0.58))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.lato(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.text.opacity(0.36))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - Rows

    private var signOutRow: some View {
        Button {
            showingSignOutConfirm = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.text.opacity(0.05))
                        .frame(width: 40, height: 40)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.lato(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.destructive)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sign out")
                        .font(.lato(size: 17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.text)
                    if let email = appState.currentUserEmail {
                        Text(email)
                            .font(.lato(size: 13))
                            .foregroundStyle(AppTheme.text.opacity(0.58))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Push row that opens `BudgetsView`. Right side shows the count of
    /// budgets currently set as a peek (e.g. "3 set" or "None set").
    private var budgetsLinkRow: some View {
        NavigationLink {
            BudgetsView()
                .environment(appState)
        } label: {
            HStack(spacing: 12) {
                Text("Budgets")
                    .font(.lato(size: 17, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                HStack(spacing: 6) {
                    Text(appState.budgets.isEmpty
                         ? "None set"
                         : "\(appState.budgets.count) set")
                        .font(.lato(size: 17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.text2)
                    Image(systemName: "chevron.right")
                        .font(.lato(size: 13, weight: .semibold))
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

    /// Single tappable row that pushes `HouseholdView` for full management.
    /// The right side shows the active household's name as a peek.
    private var householdLinkRow: some View {
        NavigationLink {
            HouseholdView()
                .environment(appState)
        } label: {
            HStack(spacing: 12) {
                Text("Household")
                    .font(.lato(size: 17, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                HStack(spacing: 6) {
                    Text(appState.currentHousehold?.name ?? "Untitled")
                        .font(.lato(size: 17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.text2)
                    Image(systemName: "chevron.right")
                        .font(.lato(size: 13, weight: .semibold))
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
                        Label("\(c.displayName.string) (\(c.code))", systemImage: "checkmark")
                    } else {
                        Text("\(c.displayName.string) (\(c.code))")
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text("Currency")
                    .font(.lato(size: 17, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                HStack(spacing: 6) {
                    Text(appState.currency.displayName)
                        .font(.lato(size: 17, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.text2)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.lato(size: 11, weight: .semibold))
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

    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        // `LocalizedStringKey` (not `String`) so SwiftUI's bundle lookup
        // resolves against the active locale; raw `String` would bypass
        // localization entirely. Existing call sites pass string
        // literals which Swift coerces to `LocalizedStringKey`.
        Text(key)
            .font(.lato(size: 13, weight: .semibold))
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
