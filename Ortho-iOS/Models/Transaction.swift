import Foundation

enum TransactionKind: String, CaseIterable, Hashable, Codable {
    case expense, income
}

struct Transaction: Identifiable, Hashable {
    let id: UUID
    var merchant: String
    var category: TransactionCategory
    var kind: TransactionKind
    /// USD cents. Always non-negative; direction comes from `kind`.
    /// e.g. $5.75 → 575; $2,850.00 → 285_000.
    var amount: Int64
    /// One or more household members responsible. `count >= 1`.
    /// For personal transactions (`householdID == nil`), exactly one.
    var ownerIDs: Set<User.ID>
    /// Explicit per-owner share of the amount, as percentages summing to 100.
    /// `nil` means split evenly across `ownerIDs`. Only meaningful for
    /// multi-owner transactions.
    var splits: [User.ID: Decimal]?
    var source: String
    var date: Date
    /// `nil` means personal (visible only to the single user in `ownerIDs`).
    /// Non-nil means shared with all members of that household.
    var householdID: Household.ID?

    init(id: UUID = UUID(),
         merchant: String,
         category: TransactionCategory,
         kind: TransactionKind,
         amount: Int64,
         ownerIDs: Set<User.ID>,
         splits: [User.ID: Decimal]? = nil,
         source: String,
         date: Date,
         householdID: Household.ID? = nil) {
        self.id = id
        self.merchant = merchant
        self.category = category
        self.kind = kind
        self.amount = amount
        self.ownerIDs = ownerIDs
        self.splits = splits
        self.source = source
        self.date = date
        self.householdID = householdID
    }

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
        cents: Int64,
        ownerIDs: Set<User.ID>,
        source: String,
        daysAgo: Int,
        hour: Int,
        minute: Int,
        householdID: Household.ID? = Household.homeSample.id
    ) -> Transaction {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let day = cal.date(byAdding: .day, value: -daysAgo, to: base) ?? base
        let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return Transaction(
            merchant: merchant,
            category: category,
            kind: kind,
            amount: cents,
            ownerIDs: ownerIDs,
            source: source,
            date: date,
            householdID: householdID
        )
    }

    static let sample: [Transaction] = {
        let maya = User.mayaSample.id
        let jordan = User.jordanSample.id
        let both: Set<User.ID> = [maya, jordan]

        return [
            // Today
            makeSample(merchant: "Blue Bottle Coffee",   category: .coffee,    kind: .expense, cents: 575,     ownerIDs: [maya],   source: "Amex Gold",      daysAgo: 0, hour: 8,  minute: 24),
            makeSample(merchant: "Whole Foods",          category: .groceries, kind: .expense, cents: 8742,    ownerIDs: [jordan], source: "Chase Sapphire", daysAgo: 0, hour: 12, minute: 8),
            makeSample(merchant: "Sweetgreen",           category: .dining,    kind: .expense, cents: 1620,    ownerIDs: [jordan], source: "Chase Sapphire", daysAgo: 0, hour: 13, minute: 14),

            // Yesterday
            makeSample(merchant: "Spotify Family",       category: .subs,      kind: .expense, cents: 1699,    ownerIDs: [maya],   source: "Apple Card",     daysAgo: 1, hour: 6,  minute: 0),
            makeSample(merchant: "Shell",                category: .fuel,      kind: .expense, cents: 4210,    ownerIDs: [jordan], source: "Chase Sapphire", daysAgo: 1, hour: 17, minute: 42),
            makeSample(merchant: "Trader Joe's",         category: .groceries, kind: .expense, cents: 5428,    ownerIDs: [maya],   source: "Amex Gold",      daysAgo: 1, hour: 18, minute: 18),

            // 2 days ago
            makeSample(merchant: "Greenwood Apartments", category: .rent,      kind: .expense, cents: 285_000, ownerIDs: both,     source: "ACH · Joint",    daysAgo: 2, hour: 9,  minute: 0),
            makeSample(merchant: "CVS Pharmacy",         category: .health,    kind: .expense, cents: 1240,    ownerIDs: [jordan], source: "Apple Card",     daysAgo: 2, hour: 11, minute: 32),
            makeSample(merchant: "Payroll — Acme Co.",   category: .income,    kind: .income,  cents: 342_000, ownerIDs: [maya],   source: "ACH · Checking", daysAgo: 2, hour: 6,  minute: 0),

            // 3 days ago
            makeSample(merchant: "Netflix",              category: .subs,      kind: .expense, cents: 2299,    ownerIDs: [maya],   source: "Apple Card",     daysAgo: 3, hour: 7,  minute: 0),
            makeSample(merchant: "Uber",                 category: .transit,   kind: .expense, cents: 1850,    ownerIDs: [maya],   source: "Amex Gold",      daysAgo: 3, hour: 21, minute: 42),
            makeSample(merchant: "ConEd",                category: .utilities, kind: .expense, cents: 9416,    ownerIDs: both,     source: "ACH · Joint",    daysAgo: 3, hour: 10, minute: 0),
        ]
    }()
}
