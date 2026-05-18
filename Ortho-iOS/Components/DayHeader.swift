import SwiftUI

/// Sticky section header — uppercase day label, subtle date, muted outgoing
/// total for the day.
struct DayHeader: View {
    let group: TransactionGroup

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 8) {
                Text(group.dayLabel.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(AppTheme.text2)
                Text(group.dateLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.text3)
            }
            Spacer()
            Text(appState.formatMoney(group.outgoingTotal))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(AppTheme.text3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(AppTheme.bg)
    }
}
