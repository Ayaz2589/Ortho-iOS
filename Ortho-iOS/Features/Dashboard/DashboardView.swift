import SwiftUI

/// Quiet placeholder so the tab has plausible content. Replace with real
/// dashboard view when wired to live data.
struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                monthSummaryCard
                jointBalanceCard
            }
            .padding(.horizontal, 16)
        }
        .background(AppTheme.bg)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text("Dashboard")
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
    }

    private var monthSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("May · so far")
                .font(.system(size: 13, weight: .semibold))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.text.opacity(0.58))

            Text("$2,847.13")
                .font(.system(size: 36, weight: .bold))
                .tracking(-0.6)
                .monospacedDigit()
                .foregroundStyle(AppTheme.text)

            Text("of $4,200 planned · 14 days left")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.text.opacity(0.58))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.text.opacity(0.05))
                    Capsule().fill(AppTheme.positive)
                        .frame(width: geo.size.width * 0.68)
                }
            }
            .frame(height: 6)
            .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var jointBalanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Joint balance")
                .font(.system(size: 13, weight: .semibold))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.text.opacity(0.58))

            HStack(alignment: .firstTextBaseline) {
                Text("$11,402.88")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.4)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text("+$320.00")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.positive)
            }

            Text("Chase Sapphire · Joint checking")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.text.opacity(0.58))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
