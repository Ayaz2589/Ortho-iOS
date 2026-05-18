import SwiftUI

/// Standalone household-management screen. Pushed from `SettingsView` via
/// `NavigationLink`. Carries its own custom large-title header (32pt bold +
/// back chevron) so the chrome stays consistent with the rest of the app's
/// hand-rolled top bars.
struct HouseholdView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddUser = false
    @State private var showingRenameHousehold = false
    @State private var pendingHouseholdName: String = ""

    private var householdMembers: [User] { appState.householdMembers }

    /// Whether a member is removable: not yourself, and not the last member.
    private func canRemove(_ u: User) -> Bool {
        u.id != appState.currentUserID && householdMembers.count > 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    householdNameRow
                    RowSeparator(density: .comfortable)
                    ForEach(householdMembers) { u in
                        UserRowView(
                            user: u,
                            detail: detail(for: u),
                            isCurrentUser: u.id == appState.currentUserID,
                            onRemove: canRemove(u)
                                ? { appState.removeMemberFromCurrentHousehold(u.id) }
                                : nil
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
            }
        }
        .background(AppTheme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .hidesTabBar()
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    ZStack {
                        Circle().fill(AppTheme.text.opacity(0.05))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Text("Household")
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
    }

    private func detail(for u: User) -> String {
        "\(appState.formatMoney(appState.monthlySpent(by: u.id))) this month"
    }

    // MARK: - Rows

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

}

#Preview("Household · Light") {
    NavigationStack {
        HouseholdView()
            .environment(AppState())
    }
    .preferredColorScheme(.light)
}

#Preview("Household · Dark") {
    NavigationStack {
        HouseholdView()
            .environment(AppState())
    }
    .preferredColorScheme(.dark)
}
