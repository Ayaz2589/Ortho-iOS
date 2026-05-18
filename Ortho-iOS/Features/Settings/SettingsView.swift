import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @State private var showingAddUser = false
    @State private var showingAddCard = false

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionLabel("Users")

                VStack(spacing: 0) {
                    ForEach(appState.users) { u in
                        UserRowView(
                            user: u,
                            detail: detail(for: u),
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

                Text("Deleting a user removes them from this list. Existing transactions keep their original owner.")
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
                showingAddUser = false
            }
            .presentationDetents([.large])
            .presentationBackground(AppTheme.bg)
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
        "\(Money.string(appState.monthlySpent(by: u.id))) this month"
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
