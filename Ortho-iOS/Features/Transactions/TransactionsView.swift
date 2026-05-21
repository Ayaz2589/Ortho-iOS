import SwiftUI

/// Filter pill above the transactions list. Composes (AND) with the
/// merchant search filter.
enum TransactionScopeFilter: String, CaseIterable, Hashable, Identifiable {
    case all, shared, personal
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all:      "All"
        case .shared:   "Shared"
        case .personal: "Personal"
        }
    }
}

/// Day-grouped transactions list — the Transactions tab. Reads users +
/// transactions from `AppState` so adds/edits in other tabs reflect here.
struct TransactionsView: View {
    var density: Density = .comfortable

    @Environment(AppState.self) private var appState
    @State private var query: String = ""
    @State private var scopeFilter: TransactionScopeFilter = .all
    @State private var showingAddTransaction = false
    @State private var selectedTransaction: Transaction?

    /// Lazily filters each group's items by both the scope filter and the
    /// merchant search. Drops empty groups so headers never appear orphaned.
    /// Scope-filtering rules (against `appState.currentUserID` and
    /// `currentHouseholdID`):
    ///   .all      — current household's shared rows + the current user's personal rows
    ///   .shared   — only current household's shared rows
    ///   .personal — only the current user's personal rows
    private var filteredGroups: [TransactionGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let groups = appState.groups
        return groups.compactMap { g in
            let hits = g.items.filter { tx in
                guard inScope(tx) else { return false }
                guard !q.isEmpty else { return true }
                return matches(tx, query: q)
            }
            return hits.isEmpty ? nil : TransactionGroup(day: g.day, items: hits)
        }
    }

    private func inScope(_ tx: Transaction) -> Bool {
        let myID = appState.currentUserID
        let householdID = appState.currentHouseholdID
        let isShared = tx.householdID != nil && tx.householdID == householdID
        let isMine = tx.householdID == nil && tx.ownerIDs == [myID]
        switch scopeFilter {
        case .all:      return isShared || isMine
        case .shared:   return isShared
        case .personal: return isMine
        }
    }

    private func matches(_ tx: Transaction, query q: String) -> Bool {
        if tx.merchant.lowercased().contains(q) { return true }
        if tx.source.lowercased().contains(q) { return true }
        if tx.category.rawValue.lowercased().contains(q) { return true }
        for owner in appState.resolveOwners(of: tx) {
            if owner.name.lowercased().contains(q) { return true }
        }
        return false
    }

    /// True when there's at least one transaction in the store — used to
    /// decide whether to render the day list or the empty state, and to
    /// hide the search + scope filter when there's nothing to filter.
    private var hasAnyTransactions: Bool {
        !appState.transactions.isEmpty
    }

    var body: some View {
        ScrollView {
            if hasAnyTransactions {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(filteredGroups) { group in
                        Section(header: DayHeader(group: group)) {
                            groupCard(group)
                        }
                    }
                    Color.clear.frame(height: 60)
                }
            } else {
                emptyState
            }
        }
        .background(AppTheme.bg)
        .safeAreaInset(edge: .top, spacing: 0) { titleAndSearch }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionSheet { tx, keepOpen in
                appState.addTransaction(tx)
                if !keepOpen {
                    showingAddTransaction = false
                }
            }
            .environment(appState)
            .presentationDetents([.large])
            .presentationBackground(AppTheme.bg)
        }
        .sheet(item: $selectedTransaction) { tx in
            TransactionDetailSheet(txID: tx.id)
                .environment(appState)
                .presentationDetents([.large])
                .presentationBackground(AppTheme.bg)
        }
    }

    @ViewBuilder
    private func groupCard(_ group: TransactionGroup) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, tx in
                SwipeActionRow(
                    onDelete: { appState.deleteTransaction(tx) }
                ) {
                    // Include the separator inside the swipe container so
                    // it slides with the row instead of staying behind.
                    VStack(spacing: 0) {
                        TransactionRow(
                            tx: tx,
                            display: appState.ownersDisplay(of: tx),
                            density: density,
                            onTap: { selectedTransaction = tx }
                        )
                        if idx < group.items.count - 1 {
                            RowSeparator(density: density)
                        }
                    }
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
                Text("Transactions")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                addButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, hasAnyTransactions ? 6 : 24)

            // Hide the search field + scope filter when there's nothing to
            // filter — keeps the empty state visually clean and matches
            // the chromeless Housing header in its empty branch.
            if hasAnyTransactions {
                SearchField(text: $query, placeholder: "Search transactions")
                    .padding(.vertical, 8)

                scopeFilterPill
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .background(AppTheme.bg)
    }

    // MARK: - Empty state

    /// Shown when `appState.transactions` is empty. Mirrors `HousingView`'s
    /// empty-state grammar — muted SF Symbol, headline, supporting copy,
    /// pill-shaped CTA.
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 14) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(AppTheme.text.opacity(0.36))
                .padding(.top, 60)
            Text("No transactions yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.text)
            Text("Log an expense or income to see it grouped by day here.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.text.opacity(0.58))
                .padding(.horizontal, 40)
                .lineSpacing(2)
            Button {
                showingAddTransaction = true
            } label: {
                Text("Add transaction")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(AppTheme.text.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    /// All | Shared | Personal segmented pill above the transactions list.
    private var scopeFilterPill: some View {
        HStack(spacing: 4) {
            ForEach(TransactionScopeFilter.allCases) { f in
                Button {
                    scopeFilter = f
                } label: {
                    Text(f.label)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.1)
                        .foregroundStyle(scopeFilter == f ? AppTheme.text : AppTheme.text.opacity(0.58))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(scopeFilter == f ? AppTheme.surface : .clear)
                                .shadow(color: scopeFilter == f ? .black.opacity(0.06) : .clear,
                                        radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(AppTheme.text.opacity(0.05))
        )
        .animation(.easeOut(duration: 0.15), value: scopeFilter)
    }

    /// Circular "+" button next to the Transactions title. Same visual
    /// treatment as `AddUserRowView`'s leading tile so the affordance feels
    /// consistent.
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
