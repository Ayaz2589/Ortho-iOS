import Foundation

/// Bridge between SwiftUI's environment locale and non-view code that
/// constructs `DateFormatter` / `NumberFormatter` imperatively.
///
/// SwiftUI's `.environment(\.locale, …)` propagates to `Text`,
/// `.formatted`, and `Date.FormatStyle` automatically — but it does
/// NOT reach formatters built outside view bodies (e.g. cached statics
/// in `Money.swift`, formatters in `InsightEngine.swift`, the
/// `TransactionGroup.dayLabel` formatter). Those read
/// `Localizer.currentLocale` instead of `Locale.current` so they
/// respect the in-app language override.
///
/// **Files that MUST KEEP reading `Locale.current` or `en_US_POSIX`:**
///   • `Services/SupabaseAPI.swift` (`SupabaseDateFormatters` — locked
///     to `en_US_POSIX` for wire-format `yyyy-MM-dd` round-trips with
///     Postgres `date` columns).
///   • Any other `Services/*.swift` date encoder that serializes to
///     Supabase.
///
/// Everywhere else in the app, read `Localizer.currentLocale`. The
/// value is pushed from `Ortho_iOSApp.swift` whenever the user's
/// `AppLanguage` selection changes.
enum Localizer {
    /// Current effective locale for non-view formatters. Defaults to
    /// `.autoupdatingCurrent` so the app behaves correctly before the
    /// first `.onChange` fires (e.g. very first render after launch).
    static var currentLocale: Locale = .autoupdatingCurrent
}

extension LocalizedStringResource {
    /// Resolve to a plain `String` against `Localizer.currentLocale`.
    /// Use when a `String` is required — `Label(_:systemImage:)`,
    /// navigation titles, string interpolation slots, `.lowercased()`,
    /// etc. For `Text` views, pass the resource directly via
    /// `Text(resource)` — SwiftUI re-resolves via the environment locale
    /// on language change automatically.
    var string: String {
        var resource = self
        resource.locale = Localizer.currentLocale
        return String(localized: resource)
    }
}
