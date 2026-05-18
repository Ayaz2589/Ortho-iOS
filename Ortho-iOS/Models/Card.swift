import Foundation

/// A payment method (credit card, debit card, ACH account, etc.) that the
/// household uses. Drives the "Paid with" dropdown in the add-transaction
/// sheet. `Transaction.source` stores the card's `name` as a string so
/// existing transactions keep their label even if a card is later renamed
/// or deleted.
struct Card: Identifiable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

extension Card {
    /// Initial seed — matches the previously hardcoded expense-source list so
    /// existing sample transactions still resolve cleanly to a card by name.
    static let sample: [Card] = [
        .init(name: "Amex Gold"),
        .init(name: "Chase Sapphire"),
        .init(name: "Apple Card"),
        .init(name: "ACH · Joint"),
    ]
}
