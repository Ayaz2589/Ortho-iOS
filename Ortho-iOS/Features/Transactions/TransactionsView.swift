import SwiftUI

/// Day-grouped transactions list — the activity tab. Reads users + transactions
/// from `AppState` so adds/edits in other tabs reflect here.
struct TransactionsView: View {
    var density: Density = .comfortable

    @Environment(AppState.self) private var appState
    @State private var query: String = ""
    @State private var showingAddTransaction = false

    /// Lazily filters each group's items by merchant; drops empty groups so
    /// you never see a header with no rows.
    private var filteredGroups: [TransactionGroup] {
        let groups = appState.groups
        guard !query.isEmpty else { return groups }
        let q = query.lowercased()
        return groups.compactMap { g in
            let hits = g.items.filter { $0.merchant.lowercased().contains(q) }
            return hits.isEmpty ? nil : TransactionGroup(day: g.day, items: hits)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(filteredGroups) { group in
                    Section(header: DayHeader(group: group)) {
                        groupCard(group)
                    }
                }
                Color.clear.frame(height: 60)
            }
        }
        .background(AppTheme.bg)
        .safeAreaInset(edge: .top, spacing: 0) { titleAndSearch }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionSheet { tx in
                appState.addTransaction(tx)
                showingAddTransaction = false
            }
            .environment(appState)
            .presentationDetents([.large])
            .presentationBackground(AppTheme.bg)
        }
    }

    @ViewBuilder
    private func groupCard(_ group: TransactionGroup) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, tx in
                TransactionRow(
                    tx: tx,
                    display: appState.ownersDisplay(of: tx),
                    density: density
                )
                if idx < group.items.count - 1 {
                    RowSeparator(density: density)
                }
            }
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var titleAndSearch: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                addButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 6)

            SearchField(text: $query, placeholder: "Search transactions")
                .padding(.vertical, 8)
        }
        .background(AppTheme.bg)
    }

    /// Circular "+" button next to the Activity title. Same visual treatment
    /// as `AddUserRowView`'s leading tile so the affordance feels consistent.
    private var addButton: some View {
        Button { showingAddTransaction = true } label: {
            ZStack {
                Circle().fill(AppTheme.text.opacity(0.05))
                    .frame(width: 36, height: 36)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add transaction")
    }
}

#Preview("Light · Comfortable") {
    TransactionsView()
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Dark · Comfortable") {
    TransactionsView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Light · Compact") {
    TransactionsView(density: .compact)
        .environment(AppState())
        .preferredColorScheme(.light)
}
