import Foundation

/// Pure-function recommendation engine. Reads a snapshot of the user's
/// data and returns a prioritized list of `Insight` values for the
/// Dashboard's `InsightsCardStack` to render.
///
/// No state, no IO, no network. Easy to reason about and to layer an LLM
/// narrative pass on top of later — that layer would consume the same
/// `[Insight]` output and add longer-form copy without touching detection.
///
/// Each rule is a private static function returning `[Insight]`. The
/// top-level `recommendations(...)` calls every rule, sorts by
/// `(severity, magnitudeCents)`, and takes the top `limit`.
///
/// Insight IDs are deterministic + period-scoped so future dismissal /
/// snooze can de-dupe across renders without a model change.
enum InsightEngine {

    // MARK: - Public entry point

    static func recommendations(
        transactions: [Transaction],
        budgets: [Budget],
        properties: [Property],
        referenceDate: Date = .now,
        calendar: Calendar = .current,
        limit: Int = 6
    ) -> [Insight] {
        guard let month = calendar.dateInterval(of: .month, for: referenceDate) else {
            return []
        }
        let priorMonth = priorMonthInterval(of: referenceDate, calendar: calendar)
        let periodKey = monthKey(referenceDate, calendar: calendar)

        var all: [Insight] = []
        all += topCategoryInsight(transactions: transactions,
                                  month: month,
                                  periodKey: periodKey)
        all += monthOverMonthCategoryDeltas(transactions: transactions,
                                            month: month,
                                            priorMonth: priorMonth,
                                            periodKey: periodKey)
        all += budgetStatusInsights(transactions: transactions,
                                    budgets: budgets,
                                    month: month,
                                    referenceDate: referenceDate,
                                    calendar: calendar,
                                    periodKey: periodKey)
        all += cashflowInsight(transactions: transactions,
                               month: month,
                               periodKey: periodKey)
        all += recurringSubscriptionsInsight(transactions: transactions,
                                              referenceDate: referenceDate,
                                              calendar: calendar,
                                              periodKey: periodKey)
        all += outlierTransactionInsights(transactions: transactions,
                                          referenceDate: referenceDate,
                                          calendar: calendar,
                                          periodKey: periodKey)
        all += dailyTrendInsight(transactions: transactions,
                                 referenceDate: referenceDate,
                                 calendar: calendar,
                                 periodKey: periodKey)
        all += mortgageAffordabilityInsight(transactions: transactions,
                                            properties: properties,
                                            month: month,
                                            periodKey: periodKey)

        // Sort: severity ascending (critical first), then magnitude desc.
        all.sort { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity < rhs.severity }
            return lhs.magnitudeCents > rhs.magnitudeCents
        }
        return Array(all.prefix(limit))
    }

    // MARK: - Rule 1 — top category

    /// "Dining is your largest category this month at $X (Y% of spend)."
    private static func topCategoryInsight(
        transactions: [Transaction],
        month: DateInterval,
        periodKey: String
    ) -> [Insight] {
        var totals: [TransactionCategory: Int64] = [:]
        for tx in transactions where tx.kind == .expense && month.contains(tx.date) {
            totals[tx.category, default: 0] += tx.amount
        }
        guard let top = totals.max(by: { $0.value < $1.value }), top.value > 0 else {
            return []
        }
        let totalSpend = totals.values.reduce(0, +)
        let share = totalSpend > 0
            ? Int((Double(top.value) / Double(totalSpend) * 100).rounded())
            : 0
        let title = "\(top.key.rawValue.capitalized) is your top category"
        let body = "\(formatMoney(top.value)) this month — \(share)% of total spend."
        return [Insight(
            id: "top-category-\(top.key.rawValue)-\(periodKey)",
            title: title,
            body: body,
            severity: .info,
            icon: top.key.symbol,
            category: top.key,
            magnitudeCents: top.value
        )]
    }

    // MARK: - Rule 2 — month-over-month category deltas

    /// "Coffee spending up 45% vs last month ($X → $Y)."
    /// Only fires when both months have non-trivial spend in the category
    /// and the change is ≥ ±25%.
    private static func monthOverMonthCategoryDeltas(
        transactions: [Transaction],
        month: DateInterval,
        priorMonth: DateInterval?,
        periodKey: String
    ) -> [Insight] {
        guard let priorMonth else { return [] }
        var current: [TransactionCategory: Int64] = [:]
        var prior:   [TransactionCategory: Int64] = [:]
        for tx in transactions where tx.kind == .expense {
            if month.contains(tx.date)      { current[tx.category, default: 0] += tx.amount }
            if priorMonth.contains(tx.date) { prior[tx.category,   default: 0] += tx.amount }
        }
        var out: [Insight] = []
        for (category, currentTotal) in current {
            let priorTotal = prior[category] ?? 0
            // Need at least $20 of prior spend to make a ratio meaningful.
            guard priorTotal >= 2_000, currentTotal >= 2_000 else { continue }
            let delta = Double(currentTotal - priorTotal) / Double(priorTotal)
            guard abs(delta) >= 0.25 else { continue }
            let pct = Int((abs(delta) * 100).rounded())
            let direction = delta > 0 ? "up" : "down"
            let severity: InsightSeverity = delta > 0 ? .warning : .positive
            let title = "\(category.rawValue.capitalized) \(direction) \(pct)% vs last month"
            let body = "\(formatMoney(priorTotal)) → \(formatMoney(currentTotal))."
            out.append(Insight(
                id: "category-delta-\(category.rawValue)-\(periodKey)",
                title: title,
                body: body,
                severity: severity,
                icon: delta > 0 ? "arrow.up.right" : "arrow.down.right",
                category: category,
                magnitudeCents: abs(currentTotal - priorTotal)
            ))
        }
        return out
    }

    // MARK: - Rule 3 — budget status

    /// Per active budget: over (.critical), 80–100% with days-left context
    /// (.warning), 50–80% (.info), or "doing well" (.positive) when the
    /// user is comfortably under late in the month.
    private static func budgetStatusInsights(
        transactions: [Transaction],
        budgets: [Budget],
        month: DateInterval,
        referenceDate: Date,
        calendar: Calendar,
        periodKey: String
    ) -> [Insight] {
        guard !budgets.isEmpty else { return [] }
        let daysInMonth = calendar.range(of: .day, in: .month, for: referenceDate)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: referenceDate)
        let daysLeft = max(0, daysInMonth - dayOfMonth)
        let monthProgress = Double(dayOfMonth) / Double(daysInMonth)

        var out: [Insight] = []
        for budget in budgets where budget.monthlyLimitCents > 0 {
            let spent = transactions.reduce(Int64(0)) { acc, tx in
                guard tx.kind == .expense,
                      tx.category == budget.category,
                      month.contains(tx.date)
                else { return acc }
                return acc + tx.amount
            }
            let fraction = Double(spent) / Double(budget.monthlyLimitCents)
            let category = budget.category

            if fraction >= 1.0 {
                let over = spent - budget.monthlyLimitCents
                out.append(Insight(
                    id: "budget-over-\(category.rawValue)-\(periodKey)",
                    title: "Over budget on \(category.rawValue.capitalized)",
                    body: "You're \(formatMoney(over)) over your \(formatMoney(budget.monthlyLimitCents)) limit with \(daysLeft) days left.",
                    severity: .critical,
                    icon: "exclamationmark.triangle.fill",
                    category: category,
                    magnitudeCents: over
                ))
            } else if fraction >= 0.85 {
                let remaining = budget.monthlyLimitCents - spent
                out.append(Insight(
                    id: "budget-warning-\(category.rawValue)-\(periodKey)",
                    title: "Approaching \(category.rawValue.capitalized) limit",
                    body: "\(formatMoney(remaining)) left of \(formatMoney(budget.monthlyLimitCents)) with \(daysLeft) days to go.",
                    severity: .warning,
                    icon: "gauge.with.dots.needle.67percent",
                    category: category,
                    magnitudeCents: spent
                ))
            } else if fraction <= 0.5 && monthProgress >= 0.7 {
                // Comfortably under, late in the month — call it a win.
                let remaining = budget.monthlyLimitCents - spent
                out.append(Insight(
                    id: "budget-under-\(category.rawValue)-\(periodKey)",
                    title: "Under budget on \(category.rawValue.capitalized)",
                    body: "\(formatMoney(remaining)) of \(formatMoney(budget.monthlyLimitCents)) still available with \(daysLeft) days left.",
                    severity: .positive,
                    icon: "checkmark.circle.fill",
                    category: category,
                    magnitudeCents: remaining
                ))
            }
        }
        return out
    }

    // MARK: - Rule 4 — cashflow / savings rate

    /// Negative net = `.critical` ("Spending exceeds income by $X").
    /// Savings rate ≥ 20% = `.positive` ("Saved $X (Y% of income)").
    /// Anything in between is too noisy — return nothing.
    private static func cashflowInsight(
        transactions: [Transaction],
        month: DateInterval,
        periodKey: String
    ) -> [Insight] {
        let income   = transactions.reduce(Int64(0)) { acc, tx in
            (tx.kind == .income  && month.contains(tx.date)) ? acc + tx.amount : acc
        }
        let expenses = transactions.reduce(Int64(0)) { acc, tx in
            (tx.kind == .expense && month.contains(tx.date)) ? acc + tx.amount : acc
        }
        let net = income - expenses
        guard income > 0 || expenses > 0 else { return [] }

        if net < 0 {
            let shortfall = -net
            return [Insight(
                id: "cashflow-negative-\(periodKey)",
                title: "Spending exceeds income",
                body: "You're \(formatMoney(shortfall)) over this month: \(formatMoney(expenses)) out vs \(formatMoney(income)) in.",
                severity: .critical,
                icon: "minus.circle.fill",
                category: nil,
                magnitudeCents: shortfall
            )]
        }
        guard income > 0 else { return [] }
        let savingsRate = Double(net) / Double(income)
        if savingsRate >= 0.20 {
            let pct = Int((savingsRate * 100).rounded())
            return [Insight(
                id: "savings-rate-strong-\(periodKey)",
                title: "Saving \(pct)% of income",
                body: "Net \(formatMoney(net)) saved this month — well above the 20% benchmark.",
                severity: .positive,
                icon: "leaf.fill",
                category: nil,
                magnitudeCents: net
            )]
        }
        return []
    }

    // MARK: - Rule 5 — recurring subscriptions

    /// Identifies merchants that look like monthly subscriptions —
    /// 3+ transactions in the trailing 6 months with intervals clustered
    /// around 28–35 days and similar amounts. Reports total monthly burn.
    private static func recurringSubscriptionsInsight(
        transactions: [Transaction],
        referenceDate: Date,
        calendar: Calendar,
        periodKey: String
    ) -> [Insight] {
        guard let window = calendar.date(byAdding: .month, value: -6, to: referenceDate) else {
            return []
        }
        // Group by case-folded merchant name so "Spotify" / "spotify" collapse.
        let recent = transactions.filter {
            $0.kind == .expense && $0.date >= window
        }
        let groups = Dictionary(grouping: recent) {
            $0.merchant.lowercased().trimmingCharacters(in: .whitespaces)
        }

        var monthlyBurnCents: Int64 = 0
        var detected: [(merchant: String, monthly: Int64)] = []
        for (_, txs) in groups where txs.count >= 3 {
            let sorted = txs.sorted { $0.date < $1.date }
            let intervalsDays = zip(sorted, sorted.dropFirst()).compactMap { a, b in
                calendar.dateComponents([.day], from: a.date, to: b.date).day
            }
            guard !intervalsDays.isEmpty else { continue }
            let monthlyHits = intervalsDays.filter { (28...35).contains($0) }.count
            // Need ≥ 80% of intervals to fall in the monthly band.
            guard Double(monthlyHits) / Double(intervalsDays.count) >= 0.8 else { continue }
            let avg = txs.reduce(Int64(0)) { $0 + $1.amount } / Int64(txs.count)
            // Original-case merchant name for display.
            let displayName = sorted.last?.merchant ?? ""
            detected.append((merchant: displayName, monthly: avg))
            monthlyBurnCents += avg
        }
        guard !detected.isEmpty else { return [] }
        detected.sort { $0.monthly > $1.monthly }
        let preview = detected.prefix(3).map { $0.merchant }.joined(separator: ", ")
        let extra = detected.count > 3 ? " + \(detected.count - 3) more" : ""
        return [Insight(
            id: "subscriptions-monthly-\(periodKey)",
            title: "Recurring monthly: ~\(formatMoney(monthlyBurnCents))",
            body: "Detected \(detected.count) recurring \(detected.count == 1 ? "charge" : "charges"): \(preview)\(extra).",
            severity: .info,
            icon: "arrow.triangle.2.circlepath",
            category: nil,
            magnitudeCents: monthlyBurnCents
        )]
    }

    // MARK: - Rule 6 — outlier transactions

    /// Flags transactions whose amount is > 2× the median for their
    /// category over the trailing 6 months. Reports the single biggest
    /// outlier this month; nothing if no category has enough history.
    private static func outlierTransactionInsights(
        transactions: [Transaction],
        referenceDate: Date,
        calendar: Calendar,
        periodKey: String
    ) -> [Insight] {
        guard let lookback = calendar.date(byAdding: .month, value: -6, to: referenceDate),
              let month = calendar.dateInterval(of: .month, for: referenceDate)
        else { return [] }
        let recent = transactions.filter { $0.kind == .expense && $0.date >= lookback }
        let byCategory = Dictionary(grouping: recent, by: \.category)

        // Median amount per category — need ≥ 5 samples to be meaningful.
        var medians: [TransactionCategory: Int64] = [:]
        for (category, txs) in byCategory where txs.count >= 5 {
            let sorted = txs.map(\.amount).sorted()
            medians[category] = sorted[sorted.count / 2]
        }

        // Find the largest current-month transaction that exceeds 2× its
        // category median.
        var bestOutlier: (tx: Transaction, multiple: Double)? = nil
        for tx in transactions where tx.kind == .expense && month.contains(tx.date) {
            guard let median = medians[tx.category], median > 0 else { continue }
            let multiple = Double(tx.amount) / Double(median)
            guard multiple >= 2.0 else { continue }
            if bestOutlier == nil || tx.amount > bestOutlier!.tx.amount {
                bestOutlier = (tx, multiple)
            }
        }
        guard let outlier = bestOutlier else { return [] }
        let dateString = DateFormatter.localized(pattern: "MMM d", locale: Localizer.currentLocale).string(from: outlier.tx.date)
        let multipleString = String(format: "%.1f×", outlier.multiple)
        let severity: InsightSeverity = outlier.tx.amount >= 50_000 ? .warning : .info
        return [Insight(
            id: "outlier-\(outlier.tx.id.uuidString)-\(periodKey)",
            title: "Unusual \(outlier.tx.category.rawValue.capitalized) charge",
            body: "\(formatMoney(outlier.tx.amount)) at \(outlier.tx.merchant) on \(dateString) — \(multipleString) the typical amount.",
            severity: severity,
            icon: "sparkle.magnifyingglass",
            category: outlier.tx.category,
            magnitudeCents: outlier.tx.amount
        )]
    }

    // MARK: - Rule 7 — daily trend (last 30 vs prior 30)

    /// Compares total expense in the trailing 30 days to the 30 days
    /// before that. Surfaces only when the swing is meaningful (≥ ±20%).
    private static func dailyTrendInsight(
        transactions: [Transaction],
        referenceDate: Date,
        calendar: Calendar,
        periodKey: String
    ) -> [Insight] {
        guard let prior30Start = calendar.date(byAdding: .day, value: -60, to: referenceDate),
              let recent30Start = calendar.date(byAdding: .day, value: -30, to: referenceDate)
        else { return [] }

        var prior: Int64 = 0
        var recent: Int64 = 0
        for tx in transactions where tx.kind == .expense {
            if tx.date >= prior30Start && tx.date < recent30Start { prior += tx.amount }
            if tx.date >= recent30Start { recent += tx.amount }
        }
        guard prior >= 10_000 else { return [] }  // need >= $100 prior to ratio meaningfully
        let delta = Double(recent - prior) / Double(prior)
        guard abs(delta) >= 0.20 else { return [] }
        let pct = Int((abs(delta) * 100).rounded())

        if delta > 0 {
            return [Insight(
                id: "trend-up-\(periodKey)",
                title: "Spending up \(pct)% over 30 days",
                body: "\(formatMoney(recent)) in the last 30 days vs \(formatMoney(prior)) the 30 before.",
                severity: .warning,
                icon: "chart.line.uptrend.xyaxis",
                category: nil,
                magnitudeCents: abs(recent - prior)
            )]
        } else {
            return [Insight(
                id: "trend-down-\(periodKey)",
                title: "Spending down \(pct)% over 30 days",
                body: "\(formatMoney(recent)) in the last 30 days vs \(formatMoney(prior)) the 30 before.",
                severity: .positive,
                icon: "chart.line.downtrend.xyaxis",
                category: nil,
                magnitudeCents: abs(recent - prior)
            )]
        }
    }

    // MARK: - Rule 8 — mortgage affordability

    /// Compares the monthly mortgage P&I against the user's current-month
    /// income. <28% = `.positive` (textbook threshold), 28–35% = `.info`,
    /// >35% = `.warning`. Skips entirely if no mortgage or no income.
    private static func mortgageAffordabilityInsight(
        transactions: [Transaction],
        properties: [Property],
        month: DateInterval,
        periodKey: String
    ) -> [Insight] {
        guard let mortgage = properties
                .compactMap(\.mortgage)
                .first,
              mortgage.monthlyPaymentCents > 0
        else { return [] }
        let monthlyIncome = transactions.reduce(Int64(0)) { acc, tx in
            (tx.kind == .income && month.contains(tx.date)) ? acc + tx.amount : acc
        }
        guard monthlyIncome > 0 else { return [] }
        let ratio = Double(mortgage.monthlyPaymentCents) / Double(monthlyIncome)
        let pct = Int((ratio * 100).rounded())

        let (severity, title): (InsightSeverity, String)
        if ratio < 0.28 {
            severity = .positive
            title    = "Mortgage at \(pct)% of income"
        } else if ratio <= 0.35 {
            severity = .info
            title    = "Mortgage at \(pct)% of income"
        } else {
            severity = .warning
            title    = "Mortgage at \(pct)% of income — high"
        }
        return [Insight(
            id: "mortgage-affordability-\(periodKey)",
            title: title,
            body: "\(formatMoney(mortgage.monthlyPaymentCents)) P&I vs \(formatMoney(monthlyIncome)) income this month. Lenders typically target below 28%.",
            severity: severity,
            icon: "house.fill",
            category: nil,
            magnitudeCents: mortgage.monthlyPaymentCents
        )]
    }

    // MARK: - Helpers

    /// `"2026-05"` — stable across renders of the same calendar month.
    private static func monthKey(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    /// The calendar month immediately preceding `date`'s month.
    private static func priorMonthInterval(
        of date: Date,
        calendar: Calendar
    ) -> DateInterval? {
        guard let priorDate = calendar.date(byAdding: .month, value: -1, to: date) else {
            return nil
        }
        return calendar.dateInterval(of: .month, for: priorDate)
    }

    /// Engine-only formatter: USD cents → "$1,234.56". The Dashboard's
    /// `InsightCard` won't pass through `AppState.formatMoney` because the
    /// engine is pure / has no environment. Display currency for the body
    /// stays USD here — fine for v1 since amounts are stored in USD cents
    /// anyway; can flow through `Money` later if multi-currency rendering
    /// inside insight bodies becomes a requirement.
    private static func formatMoney(_ cents: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(
            from: NSDecimalNumber(value: Double(cents) / 100.0)
        ) ?? "$0.00"
    }
}
