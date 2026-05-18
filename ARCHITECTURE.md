# Ortho — Architecture

Ortho is a household budgeting iOS app. Two or more people track shared
expenses and income, attribute each transaction to one or more household
members, and (for multi-owner expenses) split the amount by percentage.

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
- **No persistence yet.** All data is in-memory; transactions, users, and
  cards reset on every launch. Sample data is seeded at app start.

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
│   └── Card.swift              Payment source (name only); sample seed
├── DesignSystem/
│   ├── AppTheme.swift          Color tokens (bg, surface, text, accent, …)
│   ├── Palette.swift           OrthoColorOption — household color palette
│   ├── AppearanceMode.swift    enum system/light/dark + ColorScheme mapping
│   ├── Density.swift           comfortable / compact sizing values
│   └── Money.swift             USD formatter (Decimal-aware)
├── Components/
│   ├── UserAvatarView.swift    Initial-in-circle, palette-driven
│   ├── DayHeader.swift         Sticky day section header
│   ├── RowSeparator.swift      Inset hairline divider
│   └── SearchField.swift       Focused TextField with Cancel
└── Features/
    ├── Dashboard/
    │   └── DashboardView.swift          Placeholder cards
    ├── Transactions/
    │   ├── TransactionsView.swift       Day-grouped activity list + search
    │   ├── TransactionRow.swift         One row, tappable
    │   ├── AddTransactionSheet.swift    Dual-mode (add OR edit) form
    │   └── TransactionDetailSheet.swift Read-only view + edit/delete actions
    └── Settings/
        ├── SettingsView.swift           Users + Cards + Appearance sections
        ├── UserRowView.swift            User row + AddUserRowView + ChevronView
        ├── AddUserSheet.swift           New-user form
        ├── ColorSwatchButton.swift      Color picker swatch
        ├── CardRowView.swift            Card row + AddCardRowView
        ├── AddCardSheet.swift           New-card form
        └── AppearanceRowView.swift      Appearance mode row
```

### Folder rationale

The split is into five buckets, each answering a single question:

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
- **No `Services/`, `Persistence/`, `Repositories/`** — premature. Add them
  when persistence or networking lands.

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

- `User.placeholder` is returned when an id no longer exists (deleted user
  whose transactions are still around).
- `User.mayaSample` and `User.jordanSample` have stable hardcoded UUIDs so
  the sample transactions can reference them deterministically.
- `User.detail` was removed during the refactor — the Settings row's detail
  line is now computed (`"$X.XX this month"`).

### `Transaction`

```swift
struct Transaction: Identifiable, Hashable {
    let id: UUID
    var merchant: String
    var category: TransactionCategory
    var kind: TransactionKind            // .expense or .income — explicit
    var amount: Decimal                  // always >= 0; sign comes from kind
    var ownerIDs: Set<User.ID>           // count >= 1
    var splits: [User.ID: Decimal]?      // optional explicit percentages
    var source: String                   // free-form (card name or income source)
    var date: Date                       // see "Time" note below
}
```

`effectiveSplits` returns either `splits` directly or an even-split
distribution over `ownerIDs` when `splits` is `nil`. Callers don't branch on
nullability.

`signedAmount` / `isIncome` are computed conveniences for rendering.

### `TransactionGroup`

```swift
struct TransactionGroup: Identifiable {
    let id: Date          // start-of-day
    let day: Date
    let items: [Transaction]
    var dayLabel: String  // "Today" / "Yesterday" / weekday / "May 17"
    var dateLabel: String // "May 17"
    var outgoingTotal: Decimal
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

---

## State management

A single `@Observable` class lives at the app root and is read by every
screen via `@Environment(AppState.self)`:

```swift
@Observable
final class AppState {
    var users: [User]
    var transactions: [Transaction]
    var cards: [Card]

    // CRUD helpers
    func addUser(_:)            func addTransaction(_:)
    func updateTransaction(_:)  func deleteTransaction(_:)
    func addCard(_:)            func deleteCard(_:)

    // Lookups
    func user(_ id: User.ID) -> User
    func resolveOwners(of:) -> [User]
    func ownersDisplay(of:) -> (avatarUser: User, label: String)
    func monthlySpent(by:in:on:) -> Decimal

    // Derived
    var groups: [TransactionGroup] { TransactionGroup.group(transactions) }
}
```

Installation, in `Ortho_iOSApp.swift`:

```swift
@State private var appState = AppState()
...
RootTabView().environment(appState)
```

Per-screen UI state (search query, "showing add sheet", focus state, form
inputs) lives as `@State` on the screen itself. `AppState` only owns domain
data and the helpers needed to read it.

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
- **`Money`** — single static `NumberFormatter` (USD), with a `signed`
  variant for income rendering.

---

## Key technical decisions

### Why `@Observable`, not `ObservableObject`

iOS 17+ supports the new `@Observable` macro, which removes
`@Published` boilerplate and gives per-property change tracking. With
deployment target at iOS 26.2, this is strictly correct.

### Why `Set<User.ID>` for ownership, not a multi-owner struct

Owners are a set: order doesn't matter, duplicates are meaningless, and the
common operations are membership tests and counts. `Set` makes these O(1)
and self-documenting.

The user struct itself isn't stored on the transaction — only the id —
because users can be renamed / re-colored in Settings and we want existing
transactions to follow.

### Why `splits: [User.ID: Decimal]?` is optional

When `nil`, the amount is split evenly across `ownerIDs`. This makes 90%+
of multi-owner transactions zero-overhead: rent that's truly 50/50 doesn't
need stored data saying "50/50." `effectiveSplits` papers over the
distinction for readers.

For multi-owner expenses, `AddTransactionSheet` exposes a percentage editor
that auto-rebalances *proportionally* when one row is edited (so prior
manual adjustments survive). A small **Even** button resets the split.

### Why `Transaction.source: String` instead of `Card.ID`

Cards are user-managed in Settings. A user might delete an old card after
already logging transactions against it. Storing the name as a string means
those rows keep their label — no "Removed" placeholder, no data migration.

The trade-off: renaming a card doesn't update past transactions. This is
the correct behavior for an accounting app — the historical record reflects
what the user typed at the time.

### Why a custom `OrthoTabBar`, not SwiftUI's `TabView`

`TabView` applies its own translucency, tint, and label-weight rules that
diverge from the Ortho spec (hairline top, flat warm fill, muted-graphite
inactive labels). The custom bar in `App/RootTabView.swift` is small and
gives full control of those three things. It does not support
state-restoration / deep-link behavior — when that becomes a real
requirement, swap in `TabView` and recover the look via `.toolbarBackground`.

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
the detail sheet behind it re-renders with the new values).

It also handles delete gracefully: `tx` becomes `nil`, `Color.clear` renders
in its place, and the sheet's `.onAppear` calls `dismiss()`.

### Why `AddTransactionSheet` is dual-mode (add or edit)

Edit forms always end up duplicating the add form. The two flows differ
only in (a) initial values, (b) the nav title and action label, and (c)
whether the resulting `Transaction` keeps the old id or gets a new one.
Putting both in one struct with an `editing: Transaction?` parameter and an
explicit `init` that pre-fills `@State` removes that duplication.

### Why `@AppStorage` for appearance

The user's light/dark/system choice is a persistent preference, not domain
data. `@AppStorage("appearance")` gets persistence + automatic propagation
for free — when Settings writes the new key, `Ortho_iOSApp` (which reads
the same key) re-evaluates `.preferredColorScheme(...)` and the entire app
flips. No `AppState` plumbing needed.

### Why `Decimal`, not `Double`, for amounts

Floating-point loses pennies (`0.1 + 0.2 != 0.3`). `Decimal` uses base-10
arithmetic that matches human expectations for currency. Adds slight
verbosity (`NSDecimalNumber` conversion at the `String(format:)` boundary)
but eliminates a class of bugs.

### Why no comments in most files

Source code defaults to no comments. The exceptions are:

- File headers explaining what a file is for and any non-obvious design
  intent (e.g. "Why not SwiftUI's TabView?")
- Inline comments where the *why* would be non-obvious to a future reader.

`AddTransactionSheet.rebalance(after:)`, `TransactionGroup.group(_:)`,
`User.placeholder`, and the deletion-resilience note in `Card.swift` all
qualify. The rest of the code is named well enough to read on its own.

---

## Features (current state)

### Transactions (activity tab)

- Day-grouped list with sticky headers (Today / Yesterday / weekday / date)
- Search filters across merchant, source, category name, and owner names
- "+" button in the title bar presents `AddTransactionSheet` in add mode
- Tap any row → `TransactionDetailSheet` (read-only view)
  - **Edit** opens `AddTransactionSheet` pre-filled, preserving id
  - **Delete transaction** confirms via alert, then removes
- Add sheet supports both expense and income via a segmented control:
  - **Amount** is the headline (40pt tabular numerals, leading "$")
  - **Multi-select owner chips** drive `Transaction.ownerIDs`
  - **Split editor** appears only for multi-owner expenses; auto-rebalances
    on edit; **Even** button for one-tap reset
  - **Paid with** menu (expense) reads from `appState.cards`
  - **Date** is a `displayedComponents: [.date]` picker

### Settings tab

- **Users** section: list with monthly spent total per row; **Add user**
  row opens `AddUserSheet` (name field, color picker, live preview avatar)
- **Cards** section: user-managed payment source list; trailing destructive
  minus button on each row; **Add card** opens `AddCardSheet`
- **Appearance** section: system / light / dark rows; selection persists
  via `@AppStorage("appearance")`

### Dashboard tab

Placeholder cards (May summary + joint balance) with hardcoded values.
Real per-month spend lookup is in `AppState.monthlySpent(by:)` already —
the Dashboard would consume it when designed properly.

---

## Known gaps and out-of-scope decisions

- **No persistence.** All state is in-memory; SwiftData / a backing store
  is the obvious next step.
- **No real Dashboard.** The view exists as a placeholder.
- **No "current user" identity.** Removed `User.detail` (which carried
  "(you) · 14 transactions" as a hardcoded sample string). Reintroducing
  "(you)" requires an explicit notion of who *is* the current user —
  separable concern.
- **No user edit/delete.** Settings only adds users; the footer caption
  ("Existing transactions keep their original owner") implies delete is
  coming.
- **No category management.** Categories are a hardcoded enum.
  Considered for the same treatment as Cards but not implemented.
- **No income-source management.** Cards are an expense concept.
  `AddTransactionSheet`'s income side still uses a static list.
- **No Density toggle UI.** The plumbing exists (`comfortable / compact`)
  but no Settings toggle exposes it.
- **No accessibility audit.** Avatar/initial labels work with Dynamic Type
  but no VoiceOver pass has been done.

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
- `Features/Settings/SettingsView.swift` — Light / Dark
- `Features/Settings/AddUserSheet.swift` — Light / Dark
- `Features/Settings/AddCardSheet.swift` — Light / Dark

`#Preview` blocks generally include `.environment(AppState())` so the
canvas renders against fresh sample data.
