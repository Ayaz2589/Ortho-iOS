import Foundation

/// A day-bucket of transactions. Derived from `[Transaction]` — not stored.
/// Labels (`dayLabel`, `dateLabel`) compute from `day` so "Today" / "Yesterday"
/// stay correct as time passes.
struct TransactionGroup: Identifiable, Hashable {
    /// Start-of-day for this bucket. Stable across rebuilds so SwiftUI's diff
    /// keeps animations sensible.
    let id: Date
    let day: Date
    let items: [Transaction]

    init(day: Date, items: [Transaction]) {
        self.id = day
        self.day = day
        self.items = items
    }

    /// Sum (USD cents) of all expense rows in this day's bucket.
    var outgoingTotal: Int64 {
        items.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
    }

    /// "Today" / "Yesterday" / weekday name (e.g. "Thursday") for recent days;
    /// "May 17" if outside the relative window.
    var dayLabel: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let diff = cal.dateComponents([.day], from: day, to: today).day ?? 0
        switch diff {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2..<7:
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: day)
        default:
            return Self.shortMonthDay.string(from: day)
        }
    }

    /// Short form, e.g. "May 17". Always rendered next to `dayLabel`.
    var dateLabel: String { Self.shortMonthDay.string(from: day) }

    private static let shortMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// Groups + sorts descending by day; items within a day sorted descending
    /// by exact time.
    static func group(_ txs: [Transaction], calendar: Calendar = .current) -> [TransactionGroup] {
        let buckets = Dictionary(grouping: txs) { calendar.startOfDay(for: $0.date) }
        return buckets
            .map { (day, items) in
                TransactionGroup(day: day, items: items.sorted { $0.date > $1.date })
            }
            .sorted { $0.day > $1.day }
    }
}
