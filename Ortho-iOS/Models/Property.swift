import Foundation

/// A property the household owns or rents. One of three kinds — primary
/// home, multifamily (rental units the household owns), or rental (the
/// household is the renter). Each kind uses a different subset of the
/// optional fields below.
enum PropertyKind: String, CaseIterable, Hashable, Codable, Identifiable {
    case primaryHome, multifamily, rental

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primaryHome: "Primary home"
        case .multifamily: "Multifamily property"
        case .rental:      "Rental"
        }
    }

    var subtitle: String {
        switch self {
        case .primaryHome: "You own where you live"
        case .multifamily: "Rental units you own"
        case .rental:      "You rent your home"
        }
    }

    var symbol: String {
        switch self {
        case .primaryHome: "house"
        case .multifamily: "building.2"
        case .rental:      "key"
        }
    }

    /// True for owner-occupied and landlord-owned properties — both carry
    /// mortgages.
    var hasMortgage: Bool {
        self == .primaryHome || self == .multifamily
    }
}

struct Property: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: PropertyKind
    var address: String
    /// Optional display nickname. When `nil`, the address is the title.
    var nickname: String?

    /// Mortgage info — populated for `.primaryHome` and `.multifamily`.
    var mortgage: MortgageInfo?

    /// Lease info — populated for `.rental`.
    var lease: LeaseInfo?

    /// Rental units — populated for `.multifamily`. Empty otherwise.
    var units: [Unit]

    init(id: UUID = UUID(),
         kind: PropertyKind,
         address: String,
         nickname: String? = nil,
         mortgage: MortgageInfo? = nil,
         lease: LeaseInfo? = nil,
         units: [Unit] = []) {
        self.id = id
        self.kind = kind
        self.address = address
        self.nickname = nickname
        self.mortgage = mortgage
        self.lease = lease
        self.units = units
    }

    /// The label shown as the row title in the property list / nav header.
    var title: String { nickname ?? address }
}

extension Property {
    /// Seeded so the Housing tab isn't an empty state on first launch.
    /// Numbers picked to produce a realistic mid-life mortgage view (closed
    /// roughly a decade ago, ~6.85% rate, ~$340k remaining of a $435k loan).
    static let sample: [Property] = {
        let closing = Calendar.current.date(
            from: DateComponents(year: 2016, month: 5, day: 18)
        ) ?? Date()
        let primary = Property(
            kind: .primaryHome,
            address: "124 Oak Lane",
            mortgage: MortgageInfo(
                purchasePrice: 530_000_00,     // $530,000.00 in USD cents
                originalLoan:  435_000_00,     // $435,000.00
                annualInterestRatePercent: Decimal(string: "6.85") ?? 6.85,
                loanTermYears: 30,
                closingDate: closing,
                autoPaySource: "ACH · Joint"
            )
        )
        return [primary]
    }()
}
