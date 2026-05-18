import Foundation

/// Currency conversion + formatting. Internal storage is always USD cents
/// (`Int64`); the supplied `rate` (1 USD = N of `currency`) maps to the
/// display currency. Rates come from `AppState.rate(for:)`, which falls back
/// to `Currency.fallbackRateFromUSD` until a live FX fetch lands.
enum Money {
    /// Format USD-cents in the given currency. `leadingPlus` adds a "+"
    /// prefix (used for income rows).
    static func string(cents: Int64,
                       currency: Currency,
                       rate: Decimal,
                       leadingPlus: Bool = false) -> String {
        let amount = displayAmount(cents: cents, currency: currency, rate: rate)
        let absAmount = NSDecimalNumber(decimal: amount.magnitude)
        let body = formatter(for: currency).string(from: absAmount)
            ?? "\(currency.code) 0"
        guard leadingPlus else { return body }
        return "+\(body)"
    }

    /// Just the currency's symbol — used for the leading glyph in the
    /// add-transaction amount hero.
    static func symbol(for currency: Currency) -> String {
        formatter(for: currency).currencySymbol ?? currency.code
    }

    /// Parse a user-typed amount in `currency` and round to USD cents.
    /// Used by AddTransactionSheet on submit.
    static func toUSDCents(_ amount: Decimal,
                           from currency: Currency,
                           rate: Decimal) -> Int64 {
        guard rate > 0 else { return 0 }
        let usdDollars = amount / rate
        let centsDecimal = usdDollars * 100
        var rounded = centsDecimal
        var src = centsDecimal
        NSDecimalRound(&rounded, &src, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    /// USD-cents → display amount for pre-filling the amount field in
    /// edit mode. Rounded to `currency.fractionDigits`.
    static func toDisplayAmount(cents: Int64,
                                in currency: Currency,
                                rate: Decimal) -> Decimal {
        let raw = displayAmount(cents: cents, currency: currency, rate: rate)
        var rounded = raw
        var src = raw
        NSDecimalRound(&rounded, &src, currency.fractionDigits, .plain)
        return rounded
    }

    // MARK: - Private

    private static func displayAmount(cents: Int64,
                                      currency: Currency,
                                      rate: Decimal) -> Decimal {
        let usdDollars = Decimal(cents) / 100
        return usdDollars * rate
    }

    /// Cached formatter per currency. NumberFormatter is expensive to
    /// construct — keep one alive per code so rapid re-renders stay cheap.
    private static var formatters: [Currency: NumberFormatter] = [:]

    private static func formatter(for currency: Currency) -> NumberFormatter {
        if let f = formatters[currency] { return f }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.code
        f.locale = Locale.current
        f.minimumFractionDigits = currency.fractionDigits
        f.maximumFractionDigits = currency.fractionDigits
        formatters[currency] = f
        return f
    }
}
