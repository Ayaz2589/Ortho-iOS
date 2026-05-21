import SwiftUI

/// Picker that lets the user pre-fill `AddTransactionSheet` from one of
/// their recent transactions. The grouped day-by-day layout mirrors the
/// Transactions tab so rows feel familiar. Tap a row → callback fires
/// with the source `Transaction` and the sheet dismisses; the caller is
/// responsible for mapping it onto its form state.
struct CopyTransactionPickerSheet: View {
    let onPick: (Transaction) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Up to 40 most-recent transactions, grouped by day. 40 is a soft cap
    /// — the picker is a quick-pick affordance, not a search surface.
    private var recentGroups: [TransactionGroup] {
        let recent = appState.transactions
            .sorted { $0.date > $1.date }
            .prefix(40)
        return TransactionGroup.group(Array(recent))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetNav

            if appState.transactions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(recentGroups) { group in
                            Section(header: DayHeader(group: group)) {
                                groupCard(group)
                            }
                        }
                        Color.clear.frame(height: 24)
                    }
                }
            }
        }
        .background(AppTheme.bg)
    }

    // MARK: - Nav

    private var sheetNav: some View {
        ZStack {
            Text("Copy from recent")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .tracking(-0.3)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Group card

    @ViewBuilder
    private func groupCard(_ group: TransactionGroup) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, tx in
                Button {
                    onPick(tx)
                    dismiss()
                } label: {
                    TransactionRow(
                        tx: tx,
                        display: appState.ownersDisplay(of: tx),
                        density: .comfortable,
                        onTap: nil
                    )
                    .allowsHitTesting(false)
                }
                .buttonStyle(.plain)
                if idx < group.items.count - 1 {
                    RowSeparator(density: .comfortable)
                }
            }
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 14) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(AppTheme.text.opacity(0.36))
                .padding(.top, 60)
            Text("Nothing to copy yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.text)
            Text("Add at least one transaction and it'll show up here for fast duplication.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.text.opacity(0.58))
                .padding(.horizontal, 40)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 60)
    }
}
