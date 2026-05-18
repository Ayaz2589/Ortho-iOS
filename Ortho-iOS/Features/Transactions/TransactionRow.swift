import SwiftUI

/// One transaction row. Category tile on the left with an owner avatar
/// overlapping the bottom-right corner; merchant + meta in the middle; amount
/// + time on the right. The parent passes a pre-resolved `display` so the row
/// doesn't need to know about `AppState`.
struct TransactionRow: View {
    let tx: Transaction
    /// `(avatarUser, label)` from `AppState.ownersDisplay(of:)`.
    let display: (avatarUser: User, label: String)
    let density: Density

    var body: some View {
        HStack(spacing: 12) {
            categoryTile

            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchant)
                    .font(.system(size: density.titleSize, weight: .medium))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                meta
            }

            Spacer(minLength: 8)

            Text(Money.string(tx.signedAmount, signed: tx.isIncome))
                .font(.system(size: density.amountSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tx.isIncome ? AppTheme.positive : AppTheme.text)
        }
        .padding(.horizontal, density.pad)
        .padding(.vertical, density.pad - 4)
        .frame(minHeight: density.rowMinHeight)
        .contentShape(Rectangle())
    }

    private var categoryTile: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tx.category.tint.opacity(0.92))
                .frame(width: density.avatar + 4, height: density.avatar + 4)
                .overlay(
                    Image(systemName: tx.category.symbol)
                        .font(.system(size: density.avatar * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                )
            UserAvatarView(
                user: display.avatarUser,
                size: density.avatar * 0.52,
                ring: true,
                ringColor: AppTheme.surface
            )
            .offset(x: 3, y: 3)
        }
    }

    private var meta: some View {
        HStack(spacing: 6) {
            Text(display.label)
            Text("·").opacity(0.45)
            Text(tx.source).lineLimit(1)
        }
        .font(.system(size: density.metaSize))
        .foregroundStyle(AppTheme.text2)
    }

}
