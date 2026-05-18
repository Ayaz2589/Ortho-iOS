import Foundation
import Observation

/// Single source of truth for household users, transactions, cards, and
/// currency preferences. Held at the app root and read by every screen via
/// `@Environment(AppState.self)`.
@Observable
final class AppState {
    // MARK: - Domain

    var users: [User]
    var transactions: [Transaction]
    var cards: [Card]
    var households: [Household]

    // MARK: - Identity + active household

    /// Which user is "me" on this device. Persisted so the choice survives
    /// relaunches. Default seeded to `User.mayaSample.id`.
    var currentUserID: User.ID {
        didSet {
            UserDefaults.standard.set(currentUserID.uuidString, forKey: Self.currentUserIDKey)
        }
    }

    /// Which household is currently active. The MVP UI shows only this one
    /// household at a time; the model supports many. `nil` only happens if
    /// the user later deletes their only household — handled defensively.
    var currentHouseholdID: Household.ID? {
        didSet {
            if let id = currentHouseholdID {
                UserDefaults.standard.set(id.uuidString, forKey: Self.currentHouseholdIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.currentHouseholdIDKey)
            }
        }
    }

    private static let currentUserIDKey = "currentUserID"
    private static let currentHouseholdIDKey = "currentHouseholdID"

    // MARK: - Currency + FX

    /// User-selected display currency. Internally `Transaction.amount` stays
    /// in USD cents — `formatMoney(_:)` does the conversion at render time.
    var currency: Currency {
        didSet {
            UserDefaults.standard.set(currency.rawValue, forKey: Self.currencyKey)
        }
    }

    /// Live rates fetched from floatrates.com. Empty until first successful
    /// fetch — `rate(for:)` falls back to `Currency.fallbackRateFromUSD` in
    /// that case.
    var fxRates: [Currency: Decimal] = [:]
    var ratesLastFetched: Date?
    var ratesIsLoading: Bool = false
    var ratesError: String?

    private static let currencyKey = "currency"
    private static let fxRatesKey = "fxRates"
    private static let fxRatesFetchedAtKey = "fxRatesFetchedAt"
    private static let fxStaleAfter: TimeInterval = 24 * 60 * 60
    private static let fxURL = URL(string: "https://www.floatrates.com/daily/usd.json")!

    // MARK: - Init

    init(users: [User] = User.sample,
         transactions: [Transaction] = Transaction.sample,
         cards: [Card] = Card.sample,
         households: [Household] = [.homeSample]) {
        self.users = users
        self.transactions = transactions
        self.cards = cards
        self.households = households

        // Restore persisted current user; fall back to first user.
        let savedUserID = UserDefaults.standard.string(forKey: Self.currentUserIDKey)
            .flatMap(UUID.init(uuidString:))
        self.currentUserID = savedUserID ?? users.first?.id ?? User.mayaSample.id

        // Restore persisted active household; fall back to first.
        let savedHouseholdID = UserDefaults.standard.string(forKey: Self.currentHouseholdIDKey)
            .flatMap(UUID.init(uuidString:))
        self.currentHouseholdID = savedHouseholdID
            ?? households.first?.id

        // Restore persisted currency.
        let saved = UserDefaults.standard.string(forKey: Self.currencyKey)
            .flatMap(Currency.init(rawValue:)) ?? .usd
        self.currency = saved

        // Restore cached FX rates if present.
        if let data = UserDefaults.standard.data(forKey: Self.fxRatesKey),
           let dict = try? JSONDecoder().decode([String: Double].self, from: data) {
            var loaded: [Currency: Decimal] = [:]
            for c in Currency.allCases {
                if c == .usd { loaded[c] = 1 }
                else if let v = dict[c.code] { loaded[c] = Decimal(v) }
            }
            self.fxRates = loaded
        }
        let fetchedAt = UserDefaults.standard.double(forKey: Self.fxRatesFetchedAtKey)
        if fetchedAt > 0 {
            self.ratesLastFetched = Date(timeIntervalSince1970: fetchedAt)
        }
    }

    // MARK: - User helpers

    /// Resolve a user id; returns `User.placeholder` when no longer present
    /// (e.g. user was deleted after the transaction was logged).
    func user(_ id: User.ID) -> User {
        users.first { $0.id == id } ?? .placeholder
    }

    func addUser(_ user: User) {
        users.append(user)
    }

    func resolveOwners(of tx: Transaction) -> [User] {
        tx.ownerIDs.map { user($0) }
    }

    /// What the transaction row should render in its single avatar slot + meta
    /// line. Multi-owner transactions render a synthetic avatar with joined
    /// initials and the sage palette swatch (the legacy "joint" default).
    func ownersDisplay(of tx: Transaction) -> (avatarUser: User, label: String) {
        let owners = resolveOwners(of: tx)
        switch owners.count {
        case 0:
            return (.placeholder, "—")
        case 1:
            return (owners[0], owners[0].name)
        case 2:
            let joined = "\(owners[0].initial.prefix(1))+\(owners[1].initial.prefix(1))"
            let synthetic = User(name: "Shared",
                                 initial: joined.uppercased(),
                                 colorKey: "sage")
            return (synthetic, "\(owners[0].name) + \(owners[1].name)")
        default:
            let synthetic = User(name: "Shared", initial: "··", colorKey: "sage")
            return (synthetic, "Shared")
        }
    }

    // MARK: - Transactions

    func addTransaction(_ tx: Transaction) {
        transactions.append(tx)
    }

    /// Replace an existing transaction by id. No-op if the id isn't present.
    func updateTransaction(_ tx: Transaction) {
        guard let idx = transactions.firstIndex(where: { $0.id == tx.id }) else { return }
        transactions[idx] = tx
    }

    func deleteTransaction(_ tx: Transaction) {
        transactions.removeAll { $0.id == tx.id }
    }

    var groups: [TransactionGroup] {
        TransactionGroup.group(transactions)
    }

    /// Sum (USD cents) of this user's share of all expense transactions whose
    /// `date` falls inside the calendar month containing `referenceDate`.
    /// Solo expenses count fully; multi-owner expenses contribute
    /// `amount × split% / 100` via `Transaction.effectiveSplits`.
    func monthlySpent(
        by userID: User.ID,
        in calendar: Calendar = .current,
        on referenceDate: Date = .now
    ) -> Int64 {
        let interval = calendar.dateInterval(of: .month, for: referenceDate)
        let sum: Decimal = transactions.reduce(Decimal(0)) { acc, tx in
            guard tx.kind == .expense,
                  tx.ownerIDs.contains(userID),
                  interval?.contains(tx.date) ?? true
            else { return acc }
            let pct = tx.effectiveSplits[userID] ?? 0
            return acc + (Decimal(tx.amount) * pct / 100)
        }
        var rounded = sum
        var src = sum
        NSDecimalRound(&rounded, &src, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    // MARK: - Cards

    func addCard(_ card: Card) {
        cards.append(card)
    }

    func deleteCard(_ card: Card) {
        cards.removeAll { $0.id == card.id }
    }

    // MARK: - Households

    /// The active household, or `nil` if the user has none.
    var currentHousehold: Household? {
        guard let id = currentHouseholdID else { return nil }
        return households.first { $0.id == id }
    }

    /// Rename the active household. No-op if no active household.
    func updateHouseholdName(_ name: String) {
        guard let id = currentHouseholdID,
              let idx = households.firstIndex(where: { $0.id == id })
        else { return }
        households[idx].name = name
    }

    /// Append a member to the active household. Used by the Add member flow.
    func addMemberToCurrentHousehold(_ userID: User.ID) {
        guard let id = currentHouseholdID,
              let idx = households.firstIndex(where: { $0.id == id })
        else { return }
        if !households[idx].memberIDs.contains(userID) {
            households[idx].memberIDs.append(userID)
        }
    }

    /// Remove a member from the active household. The `User` record stays in
    /// `users` so existing transactions they participate in continue to
    /// resolve to a real name + palette. Caller is responsible for invariants
    /// (e.g. don't remove the last member).
    func removeMemberFromCurrentHousehold(_ userID: User.ID) {
        guard let id = currentHouseholdID,
              let idx = households.firstIndex(where: { $0.id == id })
        else { return }
        households[idx].memberIDs.removeAll { $0 == userID }
    }

    /// Members of the active household, resolved against `users` in the
    /// household's `memberIDs` order. Falls back to all users when there's no
    /// active household (defensive — shouldn't happen in MVP).
    var householdMembers: [User] {
        guard let h = currentHousehold else { return users }
        return h.memberIDs.compactMap { id in users.first { $0.id == id } }
    }

    // MARK: - FX rates

    /// Returns the cached/live rate when present, otherwise the hardcoded
    /// fallback. Always succeeds.
    func rate(for c: Currency) -> Decimal {
        fxRates[c] ?? c.fallbackRateFromUSD
    }

    /// Convenience: format a USD-cents amount in the current currency at
    /// the current rate. Used by every display call site.
    func formatMoney(_ cents: Int64, leadingPlus: Bool = false) -> String {
        Money.string(cents: cents,
                     currency: currency,
                     rate: rate(for: currency),
                     leadingPlus: leadingPlus)
    }

    /// Skip when the cache is fresh (< 24h); otherwise call `refreshRates`.
    func refreshRatesIfStale() async {
        if let last = ratesLastFetched,
           Date().timeIntervalSince(last) < Self.fxStaleAfter {
            return
        }
        await refreshRates()
    }

    /// One-shot fetch from floatrates.com + decode + cache. On failure, sets
    /// `ratesError` but leaves any previously cached rates in place so the
    /// app keeps working.
    func refreshRates() async {
        await MainActor.run { self.ratesIsLoading = true; self.ratesError = nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.fxURL)
            let decoded = try JSONDecoder().decode([String: FloatRate].self, from: data)

            var next: [Currency: Decimal] = [.usd: 1]
            for c in Currency.allCases where c != .usd {
                if let entry = decoded[c.rawValue] {
                    next[c] = Decimal(entry.rate)
                }
            }

            // Encode for cache: store only the currencies we support, keyed
            // by uppercase ISO code, as Double for JSON round-trippability.
            var cacheDict: [String: Double] = [:]
            for (k, v) in next where k != .usd {
                cacheDict[k.code] = NSDecimalNumber(decimal: v).doubleValue
            }
            let cacheData = try JSONEncoder().encode(cacheDict)

            let fetchedAt = Date()
            await MainActor.run {
                self.fxRates = next
                self.ratesLastFetched = fetchedAt
                self.ratesError = nil
                self.ratesIsLoading = false
                UserDefaults.standard.set(cacheData, forKey: Self.fxRatesKey)
                UserDefaults.standard.set(fetchedAt.timeIntervalSince1970,
                                          forKey: Self.fxRatesFetchedAtKey)
            }
        } catch {
            await MainActor.run {
                self.ratesError = error.localizedDescription
                self.ratesIsLoading = false
            }
        }
    }
}

// MARK: - FX decode shape

private struct FloatRate: Decodable {
    let code: String
    let rate: Double
}
