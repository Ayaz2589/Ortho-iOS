import Foundation

enum Money {
    private static let usd: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// `signed` controls whether outgoing values get a leading minus.
    /// Default mirrors the mock: outgoing reads as a bare amount; income is "+$3,420.00".
    static func string(_ d: Decimal, signed: Bool = false) -> String {
        let abs = NSDecimalNumber(decimal: d.magnitude)
        let body = usd.string(from: abs) ?? "$0.00"
        guard signed else { return body }
        return d >= 0 ? "+\(body)" : "−\(body)"
    }
}
