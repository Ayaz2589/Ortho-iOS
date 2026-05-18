import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @State private var showingAddUser = false
    @State private var showingAddCard = false
    @State private var showingRenameHousehold = false
    @State private var pendingHouseholdName: String = ""

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    /// Members of the active household, resolved against `appState.users` in
    /// the household's `memberIDs` order. Falls back to all users if no
    /// household is active (defensive — shouldn't happen in MVP).
    private var householdMembers: [User] {
        guard let h = appState.currentHousehold else { return appState.users }
        return h.memberIDs.compactMap { id in appState.users.first { $0.id == id } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionLabel("Household")

                VStack(spacing: 0) {
                    householdNameRow
                    RowSeparator(density: .comfortable)
                    currentUserRow
                    RowSeparator(density: .comfortable)
                    ForEach(householdMembers) { u in
                        UserRowView(
                            user: u,
                            detail: detail(for: u),
                            isCurrentUser: u.id == appState.currentUserID,
                            onTap: { /* TODO: detail */ }
                        )
                        RowSeparator(density: .comfortable)
                    }
                    AddUserRowView { showingAddUser = true }
                }
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Text("Members can see all Shared transactions in this household. Personal transactions are visible only to you.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text.opacity(0.36))
                    .lineSpacing(2)
                    .padding(.horizontal, 24)
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
            }
        }
        .background(AppTheme.bg)
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
        .sheet(isPresented: $showingAddUser) {
            AddUserSheet { newUser in
                appState.addUser(newUser)
                appState.addMemberToCurrentHousehold(newUser.id)
                showingAddUser = false
            }
            .presentationDetents([.large])
            .presentationBackground(AppTheme.bg)
        }
        .alert("Rename household", isPresented: $showingRenameHousehold) {
            TextField("Household name", text: $pendingHouseholdName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmed = pendingHouseholdName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { appState.updateHouseholdName(trimmed) }
            }
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .kerning(0.6)
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.text.opacity(0.58))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }

    private func detail(for u: User) -> String {
        "\(appState.formatMoney(appState.monthlySpent(by: u.id))) this month"
    }

    private var householdNameRow: some View {
        Button {
            pendingHouseholdName = appState.currentHousehold?.name ?? ""
            showingRenameHousehold = true
        } label: {
            HStack(spacing: 12) {
                Text("Name")
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

    private var currentUserRow: some View {
        Menu {
            ForEach(householdMembers) { u in
                Button {
                    appState.currentUserID = u.id
                } label: {
                    if u.id == appState.currentUserID {
                        Label(u.name, systemImage: "checkmark")
                    } else {
                        Text(u.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text("I am")
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                HStack(spacing: 6) {
                    Text(appState.user(appState.currentUserID).name)
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
