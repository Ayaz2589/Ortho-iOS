# Ortho — Architecture

Ortho is a household budgeting iOS app. Members of a household share
expenses and income, attribute each transaction to one or more household
members, and (for multi-owner expenses) split the amount by percentage.
A transaction can also be **personal** — visible only to its single owner.
Amounts are stored in USD cents internally and rendered in the user's
selected currency, with live FX rates fetched on launch.

This document describes the codebase as it stands today: structure, models,
state, design system, and the technical decisions behind them.

---

## Tech stack and targets

- **Platform:** iOS, Swift 5, SwiftUI
- **Deployment target:** iOS 26.2 (project setting in `Ortho-iOS.xcodeproj`)
- **Xcode project layout:** `PBXFileSystemSynchronizedRootGroup` — any folder
  added under `Ortho-iOS/Ortho-iOS/` is automatically included in the target.
  No `project.pbxproj` edits are needed when adding files.
- **No third-party packages.** Pure SwiftUI + Foundation.
- **Networking:** one outbound call — `URLSession.shared.data(from:)` to
  [`floatrates.com/daily/usd.json`](https://www.floatrates.com/daily/usd.json)
  for live FX rates. No auth, no backend of our own.
- **No persistence for domain data yet.** Users, transactions, cards, and
  households reset on every launch (sample data is seeded). What *does*
  persist via `UserDefaults`: currency choice, appearance preference,
  current-user id, current-household id, and the FX rate cache.

---

## File structure

```
Ortho-iOS/Ortho-iOS/
├── Ortho_iOSApp.swift          @main; installs AppState into the environment
├── App/
│   ├── AppState.swift          @Observable single-source-of-truth store
│   └── RootTabView.swift       OrthoTab + OrthoTabBar + RootTabView shell
├── Models/
│   ├── User.swift              Household member; palette extension; sample
│   ├── Transaction.swift       Expense or income; multi-owner; optional splits
│   ├── TransactionCategory.swift  Enum with SF Symbol + tint per case
│   ├── TransactionGroup.swift  Derived day buckets with Today/Yesterday labels
│   ├── Card.swift              Payment source (name only); sample seed
│   ├── Currency.swift          7-case enum + fallback rates + fraction digits
│   └── Household.swift         Named group of members; sample
├── DesignSystem/
│   ├── AppTheme.swift          Color tokens (bg, surface, text, accent, …)
│   ├── Palette.swift           OrthoColorOption — household color palette
│   ├── AppearanceMode.swift    enum system/light/dark + ColorScheme mapping
│   ├── Density.swift           comfortable / compact sizing values
│   └── Money.swift             Currency-aware formatter (USD-cents in)
├── Components/
│   ├── UserAvatarView.swift    Initial-in-circle, palette-driven
│   ├── DayHeader.swift         Sticky day section header
│   ├── RowSeparator.swift      Inset hairline divider
│   └── SearchField.swift       Focused TextField with Cancel
└── Features/
    ├── Dashboard/
    │   └── DashboardView.swift          Placeholder cards
    ├── Transactions/
    │   ├── TransactionsView.swift       Day-grouped list + search + scope filter
    │   ├── TransactionRow.swift         One row, tappable
    │   ├── AddTransactionSheet.swift    Dual-mode (add OR edit) form
    │   └── TransactionDetailSheet.swift Read-only view + edit/delete actions
    └── Settings/
        ├── SettingsView.swift           Household link, Cards, Currency, Appearance
        ├── HouseholdView.swift          Pushed screen — full household management
        ├── UserRowView.swift            User row + AddUserRowView + ChevronView
        ├── AddUserSheet.swift           New-user form
        ├── ColorSwatchButton.swift      Color picker swatch
        ├── CardRowView.swift            Card row + AddCardRowView
        ├── AddCardSheet.swift           New-card form
        └── AppearanceRowView.swift      Appearance mode row
```

### Folder rationale

Five buckets, each answering a single question:

- **`App/`** — what runs the app: entry point, root navigation, global state.
- **`Models/`** — domain types. Pure values, no SwiftUI.
- **`DesignSystem/`** — tokens and formatters. No SwiftUI views.
- **`Components/`** — small, reusable SwiftUI views with no feature-specific
  logic. If a view is meaningful in more than one screen, it lives here.
- **`Features/<screen>/`** — screen-scoped views. Co-located with their
  supporting subviews and sheets.

Two folders explicitly *not* present:

- **No `ViewModels/`** — with `@Observable` + a single root `AppState`,
  per-screen view models are ceremony for the size of this app. Views read
  state directly via `@Environment(AppState.self)`.
- **No `Services/` or `Persistence/`** — the FX fetch lives inline on
  `AppState` (small, single concern). Add a `Services/` folder when there's
  a second service or when the FX logic outgrows AppState.

---

## Domain model

### `User`

```swift
struct User: Identifiable, Hashable {
    let id: UUID
    var name: String
    var initial: String          // "M" or "M+J"
    var colorKey: String         // references OrthoColorOption.all
}
```

- `User.placeholder` is returned by `AppState.user(_:)` when an id no longer
  matches anyone in `users` (defensive — happens if a User was removed but
  a transaction still references them).
- `User.mayaSample` / `User.jordanSample` have stable hardcoded UUIDs so
  sample transactions and the seeded household reference them deterministically.
- A User can be in zero, one, or many households (the data model supports it;
  the UI currently shows one active household).

### `Household`

```swift
struct Household: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var memberIDs: [User.ID]    // ordered for stable UI
}
```

`Household.homeSample` is the seeded household ("Home", Maya + Jordan).
`memberIDs` is an array (not a set) so display order survives renames /
re-orders. The same User can be removed and re-added without losing
transaction history because their User record stays in `appState.users`.

### `Transaction`

```swift
struct Transaction: Identifiable, Hashable {
    let id: UUID
    var merchant: String
    var category: TransactionCategory
    var kind: TransactionKind             // .expense or .income — explicit
    var amount: Int64                      // USD cents; always >= 0
    var ownerIDs: Set<User.ID>             // count >= 1
    var splits: [User.ID: Decimal]?        // optional explicit percentages
    var source: String                     // free-form (card name or income source)
    var date: Date                         // see "Time" note below
    var householdID: Household.ID?         // nil = personal; non-nil = shared
}
```

- `amount` is **USD cents**, stored as `Int64`. e.g. `$5.75 → 575`. Display
  conversion to the user's selected currency happens at every render via
  `AppState.formatMoney(_:)`.
- `householdID == nil` means **personal** — `ownerIDs.count == 1` by
  invariant, and the row is visible only to the matching `currentUserID`.
  Non-nil means **shared** — every member of that household sees it.
- `effectiveSplits` returns either `splits` directly or an even-split
  distribution over `ownerIDs` when `splits` is `nil`. Callers don't branch.
- `isIncome` is a computed convenience.

### `TransactionGroup`

```swift
struct TransactionGroup: Identifiable, Hashable {
    let id: Date                  // start-of-day
    let day: Date
    let items: [Transaction]
    var dayLabel: String          // "Today" / "Yesterday" / weekday / "May 17"
    var dateLabel: String         // "May 17"
    var outgoingTotal: Int64      // USD cents
}

static func group(_ txs: [Transaction]) -> [TransactionGroup]
```

Derived, not stored. `dayLabel` computes from `Calendar.startOfDay(for:)` so
"Today / Yesterday" stays correct as time passes — no hardcoded strings.

### `TransactionCategory`

`enum` with one case per category. Each case knows its SF Symbol (used by
`TransactionRow` and the category picker) and its muted tile tint.

### `Card`

```swift
struct Card: Identifiable, Hashable {
    let id: UUID
    var name: String
}
```

Drives the "Paid with" dropdown in the add-transaction sheet. `Transaction`
stores the card's `name` string, not its id, so an existing transaction
keeps its label if the underlying card is later renamed or deleted.

### `Currency`

```swift
enum Currency: String, CaseIterable, Identifiable, Hashable, Codable {
    case usd, cad, gbp, eur, jpy, cny, bdt

    var code: String                       // ISO 4217 — "USD", "CAD", ...
    var displayName: String                // "US Dollar", "Canadian Dollar", ...
    var fractionDigits: Int                // 2 for most, 0 for JPY
    var fallbackRateFromUSD: Decimal       // used until live rate lands
}
```

7 currencies. The `code` drives `NumberFormatter.currencyCode` which handles
symbol + grouping + locale-aware formatting. `fallbackRateFromUSD` is a
hardcoded approximate value used until the first successful fetch from
floatrates.com, or when network is unavailable.

---

## State management

A single `@Observable` class lives at the app root and is read by every
screen via `@Environment(AppState.self)`:

```swift
@Observable
final class AppState {
    // Domain
    var users: [User]
    var transactions: [Transaction]
    var cards: [Card]
    var households: [Household]

    // Identity + active household (persisted via UserDefaults)
    var currentUserID: User.ID
    var currentHouseholdID: Household.ID?

    // Currency + live FX (persisted via UserDefaults)
    var currency: Currency
    var fxRates: [Currency: Decimal]
    var ratesLastFetched: Date?
    var ratesIsLoading: Bool
    var ratesError: String?

    // Domain CRUD
    func addUser(_:)
    func addTransaction(_:)       func updateTransaction(_:)
    func deleteTransaction(_:)
    func addCard(_:)              func deleteCard(_:)
    func addMemberToCurrentHousehold(_:)
    func removeMemberFromCurrentHousehold(_:)
    func updateHouseholdName(_:)

    // Lookups + derived
    func user(_ id: User.ID) -> User
    func resolveOwners(of:) -> [User]
    func ownersDisplay(of:) -> (avatarUser: User, label: String)
    func monthlySpent(by:in:on:) -> Int64
    var currentHousehold: Household?
    var householdMembers: [User]
    var groups: [TransactionGroup]

    // Currency
    func rate(for: Currency) -> Decimal
    func formatMoney(_ cents: Int64, leadingPlus: Bool = false) -> String
    func refreshRatesIfStale() async       // 24h cache window
    func refreshRates() async              // network → cache → state
}
```

Installation, in `Ortho_iOSApp.swift`:

```swift
@State private var appState = AppState()
...
RootTabView().environment(appState)
```

`RootTabView` calls `.task { await appState.refreshRatesIfStale() }` so a
fresh rate fetch happens once per launch when the 24h cache is stale.

Per-screen UI state (search query, "showing add sheet", focus state, form
inputs, scope filter) lives as `@State` on the screen itself. `AppState`
only owns domain data, identity, currency, and the helpers needed to read it.

---

## Design system

### Color tokens (`AppTheme`)

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | warm off-white | deep neutral | screen background |
| `surface` | white | near-black | inset cards / rows |
| `text` | graphite | warm off-white | primary text |
| `text2 / text3 / hairline` | `text * 0.58 / 0.36 / 0.07` | same | derived |
| `accent` | muted sand | warm tan | active affordances, links |
| `positive` | sage | lighter sage | income amounts, progress |
| `destructive` | muted brick | softer salmon | Delete actions only |

Every token pairs a light and dark value via a `Color(light:dark:)` helper
that wraps `UITraitCollection.userInterfaceStyle`. No `Color`-literal
hardcoding outside of `AppTheme` and `Palette`.

### Household palette (`OrthoColorOption`)

Six muted swatches: `peach, slate, sage, terracotta, mauve, sand`. Each is
a `(bg, fg)` pair. Users carry a `colorKey` and resolve to a palette entry
via `User.palette`. Used by `UserAvatarView`, the chip rows in the
add-transaction sheet, and the color picker in `AddUserSheet`.

Do not add saturated colors to this list — calm is a design constraint.

### Other DesignSystem types

- **`Density`** — `.comfortable` or `.compact`. Drives row min height, font
  sizes, avatar diameter, padding values for the activity list. Currently
  hardcoded to `.comfortable` everywhere but the value is plumbed through.
- **`AppearanceMode`** — `system / light / dark` with `ColorScheme?` mapping.
- **`Money`** — currency-aware formatter. Public surface:
  `string(cents:currency:rate:leadingPlus:)`, `symbol(for:)`,
  `toUSDCents(_:from:rate:)`, `toDisplayAmount(cents:in:rate:)`. Cached
  per-currency `NumberFormatter` keeps rapid re-renders cheap.

---

## Key technical decisions

### Why `@Observable`, not `ObservableObject`

iOS 17+ supports the new `@Observable` macro, which removes `@Published`
boilerplate and gives per-property change tracking. With deployment target
at iOS 26.2, this is strictly correct.

### Why amounts are `Int64` USD cents

Floating-point loses pennies. `Decimal` is precise but verbose at every
boundary. `Int64` of USD cents is exact, naturally bounded for currency
math, and matches how most accounting systems represent money. Sums are
exact integer addition. The display path multiplies `Decimal(cents) / 100
× rate` (Decimal kept for the rate math) and rounds back to the currency's
fraction digits at render time.

### Why live FX rates with a fallback

The app's primary metric is "how much did we spend?" so a stale conversion
is more wrong than a missing currency code. Live rates from floatrates.com
(free, no API key, includes BDT — most ECB-based feeds don't) keep the
display honest. The 24h cache + hardcoded fallback means the app always
renders something sensible: live → cached (< 24h) → cached (stale) →
hardcoded fallback, in that order of preference.

### Why `Set<User.ID>` for ownership, not a multi-owner struct

Owners are a set: order doesn't matter, duplicates are meaningless, and the
common operations are membership tests and counts. `Set` makes these O(1)
and self-documenting. The User struct itself isn't stored on the transaction
— only the id — because users can be renamed / re-colored / re-added to a
household in Settings and we want existing transactions to follow.

### Why `splits: [User.ID: Decimal]?` is optional

When `nil`, the amount is split evenly across `ownerIDs`. This makes 90%+
of multi-owner transactions zero-overhead: rent that's truly 50/50 doesn't
need stored data saying "50/50." `effectiveSplits` papers over the
distinction for readers. The add-sheet's percentage editor auto-rebalances
*proportionally* when one row is edited (prior manual adjustments survive);
an **Even** button resets the split.

### Why `Transaction.householdID: Household.ID?` instead of a `scope` enum

`householdID == nil ⇒ personal` is one indirection rather than two
(`scope == .personal` + a separate optional `householdID`). Personal
transactions have a single owner anyway (`ownerIDs.count == 1` by
invariant), so the model collapses cleanly. The Activity-list filter
(`.all / .shared / .personal`) and `AddTransactionSheet`'s Shared|Personal
toggle both derive from this single field.

### Why `Transaction.source: String` instead of `Card.ID`

Cards are user-managed in Settings. A user might delete an old card after
already logging transactions against it. Storing the name as a string means
those rows keep their label — no "Removed" placeholder, no data migration.
Same reasoning as why ownerIDs survives member removal: the User record
stays in `users` even if removed from `currentHousehold.memberIDs`.

### Why `currentUserID` exists but has no picker UI

The current user is the anchor for **Personal** transactions (whose
ownership is just `[currentUserID]`) and for the `(you)` marker on the
household member row. Without it, "Personal" has no meaning. The original
prototype had an "I am" Menu that let you switch perspective; it was
removed because it was effectively a dev affordance on a single-user
device. The field defaults to the first household member on first launch
and survives via UserDefaults. When real auth lands, it'll be set from the
session.

### Why `HouseholdView` is its own pushable screen, not inline in Settings

Settings was getting long (Cards + Currency + Appearance + a 4-row
household section). The household has enough affordances (rename, member
list, add, remove) that it deserves its own surface. `SettingsView` now
keeps a single "Household — <name> ›" row that NavigationLinks into the
full editor. Both screens hide the system nav bar via `.toolbar(.hidden,
for: .navigationBar)` and use a custom large-title `safeAreaInset` header
to match the rest of the app's chrome.

### Why a custom `OrthoTabBar`, not SwiftUI's `TabView`

`TabView` applies its own translucency, tint, and label-weight rules that
diverge from the Ortho spec (hairline top, frosted glass via
`.ultraThinMaterial`, muted-graphite inactive labels). The custom bar is
small and gives full control. It does not support state-restoration /
deep-link behavior — when that becomes a real requirement, swap in
`TabView` and recover the look via `.toolbarBackground`.

### Why `date: Date` even though the UI never shows time

Removing the time *concept* from the user-facing app is intentional: the
DatePicker is `displayedComponents: [.date]`, the row's right column shows
only the amount. But the underlying type stays `Date` because:

1. `Calendar.startOfDay(for:)` derives day grouping correctly even across
   DST boundaries — it can't with a hand-rolled "day only" type.
2. The time portion (set to `.now` when adding) doubles as an implicit
   ordering signal for transactions logged on the same day. The user sees
   nothing; the sort stays stable.

### Why detail sheet looks up by id, not by snapshot

`TransactionDetailSheet` takes `txID: Transaction.ID` and re-reads the live
transaction from `AppState` on every render. This means edits propagate to
the open detail sheet automatically (you save changes in the edit sheet,
the detail sheet behind it re-renders with the new values). It also
handles delete gracefully: `tx` becomes `nil`, `Color.clear` renders in
its place, and the sheet's `.onAppear` calls `dismiss()`.

### Why `AddTransactionSheet` is dual-mode (add or edit)

Edit forms always end up duplicating the add form. The two flows differ
only in (a) initial values, (b) the nav title and action label, and (c)
whether the resulting `Transaction` keeps the old id or gets a new one.
Putting both in one struct with an `editing: Transaction?` parameter and
an explicit `init` that pre-fills `@State` removes that duplication.

### Why an `originalAmountText` round-trip mitigation in edit mode

The amount is stored in USD cents but displayed in the user's currency.
Re-opening an existing transaction in CNY (or any non-USD currency) would
mean: stored cents → display amount → user re-saves → display amount →
stored cents. That round-trip introduces sub-cent rounding error (and full
yen errors for JPY). The edit sheet snapshots the formatted amount string
on appear; on save, if the field is unchanged, we reuse `editing.amount`
directly instead of re-converting. So editing non-amount fields never
shifts the stored cents.

### Why `.lineLimit(1)` + `.minimumScaleFactor(...)` on every money render

Wide currencies (CN¥, BDT prefix, ৳) plus comma-grouped digits can overflow
the right column of a transaction row or the amount hero on a sheet. Hard
truncation would hide cents (`$1,234.5…` is dangerous in an accounting
context). `.lineLimit(1)` keeps the value on one line; `.minimumScaleFactor`
lets SwiftUI shrink the font before wrapping. Tuned per surface: 0.6 for
list rows, 0.5 for the 40pt amount heroes, 0.7 for the 12pt day-total.

### Why `@AppStorage` for appearance, `UserDefaults` directly for the rest

Appearance is a pure UI preference and the change site (Settings) is
right next to the read site (`Ortho_iOSApp`). `@AppStorage` is the right
SwiftUI primitive — it persists and propagates automatically. The other
persisted preferences (currency, currentUserID, currentHouseholdID, FX
cache) live on `AppState` because they're read by many call sites and
participate in `@Observable` change tracking. `AppState.init` reads from
`UserDefaults` once; `didSet` writes back on every change.

### Why no comments in most files

Source code defaults to no comments. The exceptions are:

- File headers explaining what a file is for and any non-obvious design
  intent (e.g. "Why not SwiftUI's TabView?")
- Inline comments where the *why* would be non-obvious to a future reader.

`AddTransactionSheet.rebalance(after:)`, `TransactionGroup.group(_:)`,
`User.placeholder`, the deletion-resilience note in `Card.swift`, the
`originalAmountText` rationale, and the FX `MainActor.run` blocks all
qualify. The rest is named well enough to read on its own.

---

## Features (current state)

### Transactions (activity tab)

- Day-grouped list with sticky headers (Today / Yesterday / weekday / date)
- **Scope filter pill** below the search field: All / Shared / Personal
- Search filters across merchant, source, category name, and owner names
- "+" button in the title bar presents `AddTransactionSheet` in add mode
- Tap any row → `TransactionDetailSheet` (read-only view)
  - **Edit** opens `AddTransactionSheet` pre-filled, preserving id
  - **Delete transaction** confirms via alert, then removes
  - Nav title surfaces scope: "Expense · Home" or "Personal expense"
- Add sheet supports both expense and income via a segmented control,
  plus a **Shared | Personal** scope toggle above it:
  - **Amount** is the headline, currency symbol from `Money.symbol(for:)`
  - **Multi-select owner chips** (shared only) drive `Transaction.ownerIDs`
    — chips iterate `appState.householdMembers` so removed members don't
    appear in new transactions
  - **Split editor** appears only for multi-owner shared expenses; auto-
    rebalances on edit; **Even** button for one-tap reset
  - **Paid with** menu (expense) reads from `appState.cards`
  - **Date** is a `displayedComponents: [.date]` picker

### Settings tab

- **Household** section — single push row showing the active household's
  name. NavigationLinks to `HouseholdView` for the full editor.
- **Cards** section — user-managed payment source list with destructive
  minus button per row; **Add card** opens `AddCardSheet`.
- **Currency** section — single Menu row with all 7 currencies (checkmark
  on the active one). Below the card: a rates-freshness caption
  ("Rates updated 2 minutes ago" / "Updating rates…" / "Rates unavailable;
  using approximate values").
- **Appearance** section — system / light / dark rows; selection persists
  via `@AppStorage("appearance")`.
- Bottom: a 60pt `Color.clear` spacer because the NavigationStack +
  toolbar-hidden chrome interferes with the bottom tab bar's
  safe-area-inset propagation.

### Household screen (pushed from Settings)

- Custom large-title header ("Household") with a circular back chevron
- **Name** row → tap opens a SwiftUI `.alert` with a TextField for renaming
- **Member list** — each row is `UserRowView` showing the member's avatar,
  name, monthly-spent total ("(you) · $X this month" on the current user),
  and a destructive minus button (`onRemove`). Removing a member detaches
  them from `currentHousehold.memberIDs` but keeps the User record so
  existing transactions still resolve their name + palette.
  - Minus is hidden for the current user and for the last remaining member.
- **Add member** → `AddUserSheet` (name + 6-color picker + live preview);
  on add, the new user is appended to both `appState.users` and
  `currentHousehold.memberIDs`.

### Dashboard tab

Placeholder cards (May summary + joint balance) with hardcoded strings.
Real data lookups exist (`AppState.monthlySpent(by:)`) but the Dashboard
hasn't been redesigned around them.

---

## Known gaps and out-of-scope decisions

- **No persistence for domain data.** Users, transactions, cards, households
  reset on every launch. SwiftData / a backing store is the obvious next
  step. (Preferences and FX cache *do* persist via UserDefaults.)
- **No real Dashboard.** Placeholder cards with hardcoded strings.
- **Single household in the UI.** The data model supports many — `households:
  [Household]` and `currentHouseholdID: Household.ID?` — but there's no
  household switcher. Adding one is mostly UI: a picker in Settings or a
  segmented header on Transactions.
- **No transfers between members.** Iteration 2 work. Transfer model,
  Add Transfer sheet, balance computation, separate display in Activity.
- **No current-user picker UI.** `currentUserID` exists in state but isn't
  user-editable. Defaults to first member on first launch.
- **No category management.** Categories are a hardcoded enum. Could get
  the same treatment as Cards (user-managed list) when there's a real
  need to add custom ones.
- **No income-source management.** Cards are an expense concept;
  `AddTransactionSheet`'s income side still uses a static list of three
  options (ACH · Checking / ACH · Joint / Wire).
- **No Density toggle UI.** The plumbing exists (`comfortable / compact`)
  but no Settings toggle exposes it.
- **No accessibility audit.** Labels exist on destructive buttons and
  the avatar/initial Text scales with Dynamic Type, but no VoiceOver pass
  has been done.
- **No FX refresh on foreground.** Rates fetch once per launch when the
  24h cache is stale. A long-lived session won't pick up newer rates
  without a scene-phase listener.
- **Round-trip currency precision loss.** USD cents is a lossy base for
  currencies with much larger units (JPY, BDT). Typing ¥9 stores 6 cents
  which displays back as ¥9 (rounded). For currencies near USD scale
  (CAD/EUR/GBP) the loss is sub-cent. The `originalAmountText` mitigation
  in `AddTransactionSheet` preserves stored cents when the user doesn't
  touch the amount field.

---

## Verification

To confirm the project builds cleanly:

```sh
xcodebuild \
  -project Ortho-iOS.xcodeproj \
  -scheme Ortho-iOS \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build
```

Expect `** BUILD SUCCEEDED **`. Inside Xcode, `⌘R` runs against the
iPhone 17 / iOS 26.2 simulator with sample data seeded.

Preview blocks live on the screen-level views and the standalone sheets:

- `App/RootTabView.swift` — Root · Light / Dark
- `Features/Transactions/TransactionsView.swift` — three density variants
- `Features/Transactions/TransactionDetailSheet.swift` — solo / joint / income
- `Features/Transactions/AddTransactionSheet.swift` — Light / Dark
- `Features/Settings/SettingsView.swift` — Light / Dark
- `Features/Settings/HouseholdView.swift` — Light / Dark
- `Features/Settings/AddUserSheet.swift` — Light / Dark
- `Features/Settings/AddCardSheet.swift` — Light / Dark

`#Preview` blocks generally include `.environment(AppState())` so the
canvas renders against fresh sample data.
