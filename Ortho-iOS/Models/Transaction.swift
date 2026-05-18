import Foundation

enum TransactionKind: String, CaseIterable, Hashable, Codable {
    case expense, income
}

struct Transaction: Identifiable, Hashable {
    let id: UUID
    var merchant: String
    var category: TransactionCategory
    var kind: TransactionKind
    /// Always non-negative. Sign is conveyed by `kind`.
    var amount: Decimal
    /// One or more household members responsible. `count >= 1`.
    var ownerIDs: Set<User.ID>
    /// Explicit per-owner share of the amount, as percentages summing to 100.
    /// `nil` means split evenly across `ownerIDs`. Only meaningful for
    /// multi-owner transactions.
    var splits: [User.ID: Decimal]?
    var source: String
    var date: Date

    init(id: UUID = UUID(),
         merchant: String,
         category: TransactionCategory,
         kind: TransactionKind,
         amount: Decimal,
         ownerIDs: Set<User.ID>,
         splits: [User.ID: Decimal]? = nil,
         source: String,
         date: Date) {
        self.id = id
        self.merchant = merchant
        self.category = category
        self.kind = kind
        self.amount = amount
        self.ownerIDs = ownerIDs
        self.splits = splits
        self.source = source
        self.date = date
    }

    /// Sign-corrected amount for rendering ("+$3,420.00" / "-$5.75").
    var signedAmount: Decimal { kind == .income ? amount : -amount }
    var isIncome: Bool { kind == .income }

    /// Resolved per-owner percentages — always returns a value, deriving an
    /// even split when `splits` is `nil`. Returns an empty dict for empty
    /// `ownerIDs` (shouldn't happen by invariant, but safe).
    var effectiveSplits: [User.ID: Decimal] {
        if let splits, !splits.isEmpty { return splits }
        let count = ownerIDs.count
        guard count > 0 else { return [:] }
        let per = Decimal(100) / Decimal(count)
        return Dictionary(uniqueKeysWithValues: ownerIDs.map { ($0, per) })
    }
}

// MARK: - Sample data

extension Transaction {
    /// Builds a sample transaction at `hour:minute` on a day `daysAgo` from
    /// today. Kept private to keep the sample-data spelling readable.
    private static func makeSample(
        merchant: String,
        category: TransactionCategory,
        kind: TransactionKind,
        amount: Decimal,
        ownerIDs: Set<User.ID>,
        source: String,
        daysAgo: Int,
        hour: Int,
        minute: Int
    ) -> Transaction {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let day = cal.date(byAdding: .day, value: -daysAgo, to: base) ?? base
        let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return Transaction(
            merchant: merchant,
            category: category,
            kind: kind,
            amount: amount,
            ownerIDs: ownerIDs,
            source: source,
            date: date
        )
    }

    static let sample: [Transaction] = {
        let maya = User.mayaSample.id
        let jordan = User.jordanSample.id
        let both: Set<User.ID> = [maya, jordan]

        return [
            // Today
            makeSample(merchant: "Blue Bottle Coffee",   category: .coffee,    kind: .expense, amount: 5.75,    ownerIDs: [maya],   source: "Amex Gold",      daysAgo: 0, hour: 8,  minute: 24),
            makeSample(merchant: "Whole Foods",          category: .groceries, kind: .expense, amount: 87.42,   ownerIDs: [jordan], source: "Chase Sapphire", daysAgo: 0, hour: 12, minute: 8),
            makeSample(merchant: "Sweetgreen",           category: .dining,    kind: .expense, amount: 16.20,   ownerIDs: [jordan], source: "Chase Sapphire", daysAgo: 0, hour: 13, minute: 14),

            // Yesterday
            makeSample(merchant: "Spotify Family",       category: .subs,      kind: .expense, amount: 16.99,   ownerIDs: [maya],   source: "Apple Card",     daysAgo: 1, hour: 6,  minute: 0),
            makeSample(merchant: "Shell",                category: .fuel,      kind: .expense, amount: 42.10,   ownerIDs: [jordan], source: "Chase Sapphire", daysAgo: 1, hour: 17, minute: 42),
            makeSample(merchant: "Trader Joe's",         category: .groceries, kind: .expense, amount: 54.28,   ownerIDs: [maya],   source: "Amex Gold",      daysAgo: 1, hour: 18, minute: 18),

            // 2 days ago
            makeSample(merchant: "Greenwood Apartments", category: .rent,      kind: .expense, amount: 2850.00, ownerIDs: both,     source: "ACH · Joint",    daysAgo: 2, hour: 9,  minute: 0),
            makeSample(merchant: "CVS Pharmacy",         category: .health,    kind: .expense, amount: 12.40,   ownerIDs: [jordan], source: "Apple Card",     daysAgo: 2, hour: 11, minute: 32),
            makeSample(merchant: "Payroll — Acme Co.",   category: .income,    kind: .income,  amount: 3420.00, ownerIDs: [maya],   source: "ACH · Checking", daysAgo: 2, hour: 6,  minute: 0),

            // 3 days ago
            makeSample(merchant: "Netflix",              category: .subs,      kind: .expense, amount: 22.99,   ownerIDs: [maya],   source: "Apple Card",     daysAgo: 3, hour: 7,  minute: 0),
            makeSample(merchant: "Uber",                 category: .transit,   kind: .expense, amount: 18.50,   ownerIDs: [maya],   source: "Amex Gold",      daysAgo: 3, hour: 21, minute: 42),
            makeSample(merchant: "ConEd",                category: .utilities, kind: .expense, amount: 94.16,   ownerIDs: both,     source: "ACH · Joint",    daysAgo: 3, hour: 10, minute: 0),
        ]
    }()
}
