import Foundation
import Observation

/// Single source of truth for household users and transactions. Held at the
/// app root and read by every screen via `@Environment(AppState.self)`.
@Observable
final class AppState {
    var users: [User]
    var transactions: [Transaction]
    var cards: [Card]

    init(users: [User] = User.sample,
         transactions: [Transaction] = Transaction.sample,
         cards: [Card] = Card.sample) {
        self.users = users
        self.transactions = transactions
        self.cards = cards
    }

    /// Resolve a user id; returns `User.placeholder` when no longer present
    /// (e.g. user was deleted after the transaction was logged).
    func user(_ id: User.ID) -> User {
        users.first { $0.id == id } ?? .placeholder
    }

    func addUser(_ user: User) {
        users.append(user)
    }

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

    func addCard(_ card: Card) {
        cards.append(card)
    }

    func deleteCard(_ card: Card) {
        cards.removeAll { $0.id == card.id }
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

    var groups: [TransactionGroup] {
        TransactionGroup.group(transactions)
    }

    /// Sum of this user's share of all expense transactions whose `date` falls
    /// inside the calendar month containing `referenceDate`. Solo expenses
    /// count fully; multi-owner expenses contribute `amount × split% / 100`
    /// via `Transaction.effectiveSplits`.
    func monthlySpent(
        by userID: User.ID,
        in calendar: Calendar = .current,
        on referenceDate: Date = .now
    ) -> Decimal {
        let interval = calendar.dateInterval(of: .month, for: referenceDate)
        return transactions.reduce(Decimal(0)) { acc, tx in
            guard tx.kind == .expense,
                  tx.ownerIDs.contains(userID),
                  interval?.contains(tx.date) ?? true
            else { return acc }
            let pct = tx.effectiveSplits[userID] ?? 0
            return acc + (tx.amount * pct / 100)
        }
    }
}
