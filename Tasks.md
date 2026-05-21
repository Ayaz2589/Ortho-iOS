# Ortho — Tasks

Lightweight Kanban for backend integration and other in-flight work. Move
items between sections as they progress. Date the entry when you start or
finish so the history is preserved.

---

## In progress

_(none)_

---

## To do

### Setup

- [x] Set up Supabase CLI locally (`supabase login`, `supabase init`, `supabase link --project-ref brujhxmtzfgowimprueo`). CLI installed via direct binary download (CLT was too stale for the brew formula); linked to remote project.
- [ ] Verify own domain in Resend (later, when we wire household invitations — `onboarding@resend.dev` can only send to your own verified email)

### Schema (Postgres — see Spec section below)

- [x] Draft schema: `households`, `household_members`, `pending_invites`, `transactions`, `transaction_shares`, plus the existing housing tables (`properties`, `mortgage_info`, `lease_info`, `units`, `rental_payments`) and `cards` → `supabase/migrations/20260521120000_initial_schema.sql`
- [x] Define enums: `role` (`owner | member` for v1; `admin` deferred), `kind` (`expense | income`), `scope` (`personal | shared`), plus `property_kind` and `transaction_category`
- [x] Add CHECK constraints (`amount_non_negative`, `scope_matches_household`, `lease_dates_ordered`, percent range, non-negative cents on every money column)
- [x] Write RLS policies per table — security-definer `is_household_member` / `is_household_owner` / `is_property_household_member` helpers break recursion on `household_members`
- [x] Write `accept_invite(token)` RPC function — sha256 the raw token, lookup unredeemed + unexpired row, idempotent membership insert, mark redeemed
- [x] Run schema SQL against Supabase — applied via `supabase db push` against project `brujhxmtzfgowimprueo`

### Swift models

- [x] Add `HouseholdMember` model (with `role` field)
- [x] Add `PendingInvite` model
- [x] Add `LocalUser` model (device-only; persisted in JSON cache, never sent to backend)
- [x] Rename `Transaction.ownerIDs` semantics: for shared transactions, IDs are `User.ID` (= `auth.uid()`) of Ortho users only. Local-user owners only appear on personal-scope transactions and stay on device.
- [x] Add `Transaction.scope` (`personal | shared`) and `Transaction.createdBy: User.ID`
- [x] Make `User` Codable (match schema)
- [x] Make `Transaction` Codable
- [x] Cross-check existing Codable models against schema. Added `householdID` to `Property` + `Card`; made `Card` Codable. `Household` / `MortgageInfo` / `LeaseInfo` / `Unit` / `RentalPayment` were already Codable and align field-for-field. `Currency` stays as a device-only UI preference (no schema mapping).

### Auth

- [x] Build sign-in screen (email → 6-digit OTP code → session)
- [x] Gate `RootTabView` behind auth state via `appState.session`
- [x] Auth-state observer (`observeAuthChanges`) restores session on launch + tracks sign-in/out
- [x] Sign-out UI in Settings (Account section + destructive confirmation alert)
- [x] `currentUserID` now driven by `session.user.id` via `ensureCurrentUser`; new auth users are seeded into `users` and the active household automatically
- [ ] Magic-link deep-link flow (`ortho://auth-callback` URL scheme) — later polish; OTP code works without it

### Data layer

- [x] Thin API client wrapper around `supabase-swift` — new `Services/` folder with `SupabaseAPI.swift` (error types + date strategies) and per-resource API structs
- [x] Migrate `AppState.transactions` CRUD to Supabase (respecting RLS / `created_by`). `TransactionsAPI` handles the transactions ↔ transaction_shares split; `AppState.addTransaction/updateTransaction/deleteTransaction` are now optimistic + rollback on failure.
- [x] Migrate `AppState.properties` CRUD — `PropertiesAPI` coordinates `properties` + `mortgage_info` + `lease_info` + `units` (parallel reads, sub-table delete-and-reinsert on update, FK cascade on delete). Date columns encoded as `yyyy-MM-dd` strings.
- [x] Migrate `AppState.rentalPayments` CRUD — `RentalPaymentsAPI` (fetch/create/delete, no update — matches UI).
- [x] Migrate `AppState.cards` CRUD — `CardsAPI` (fetch/create/delete, no update — cards are immutable post-creation).
- [x] Migrate household + member management — `HouseholdsAPI` with `findOrCreate` (used by bootstrap), `updateName`, `removeMember`. **Add-member is disabled** in `HouseholdView` until the Invitations flow lands (in-memory User would FK-violate `public.users.id`).
- [x] Optimistic update plumbing with rollback-on-failure — applied to every CRUD method across all resources. Pattern: snapshot → optimistic mutation → background Task → rollback + `dataError` on throw.

### Invitations

- [ ] "Invite member" sheet (email entry + QR view)
- [ ] Server: insert `pending_invites` row with `token_hash`; send magic-link / OTP via Supabase Auth
- [ ] Render QR code from invitation deep link (Core Image — no third-party lib)
- [ ] On magic-link deep-link / QR scan → app opens → auth → call `accept_invite(token)` RPC
- [ ] Surface revoke / regenerate invitation UI
- [ ] Block new inserts by removed members (RLS already enforces, but UX should hide stale memberships)

### Caching

- [ ] JSON-on-disk cache via `Codable`
- [ ] Read cache on launch; refresh from server in background
- [ ] Write cache on every mutation
- [ ] Persist local users (device-only) in the cache alongside server-synced data

### Recommendations + Budgets

- [x] Per-category monthly budgets (server-backed `public.budgets` table with RLS, `BudgetsAPI`, optimistic AppState CRUD)
- [x] Budgets management screen (`Features/Budgets/BudgetsView` + `EditBudgetSheet`), pushed from Settings
- [x] Budget progress widget on Dashboard (`BudgetProgressCard`), hides when no budgets set
- [x] Rule-based `InsightEngine` — 8 rules: top category, MoM category delta, budget status, cashflow / savings rate, recurring subscriptions, outlier transactions, daily trend, mortgage affordability
- [x] Dashboard `InsightsCardStack` at the top, severity-tinted `InsightCard`s, hides on empty
- [ ] Optional LLM narrative layer over the same `[Insight]` output (later, when there's a clear win over templates)
- [ ] Insight dismissal / snooze persistence (IDs already period-scoped to support this)

### Transactions UX

- [x] Empty state on the Transactions tab when there are no rows yet (icon + "No transactions yet" + "Add transaction" CTA, mirrors Housing's grammar)
- [x] Loading skeleton on the Transactions tab during initial bootstrap fetch (`isLoadingInitialData` flag on AppState, `TransactionSkeletonList` with subtle opacity pulse)
- [x] Multi-add — "Save and add another" capsule below the form preserves scope/kind/source/date/owners and resets merchant/amount/category/splits
- [x] Copy from recent — picker sheet inside `AddTransactionSheet` (40 most-recent transactions grouped by day) pre-fills every field with a fresh id + today's date
- [x] Swipe-copy on transaction rows — `SwipeActionRow` reveals a `[Copy] [Delete]` tray; Copy opens AddTransactionSheet via the same `copying:` init path
- [ ] Same skeleton + empty-state treatment on Dashboard widgets and Housing (currently flicker the empty state during bootstrap; reuse `isLoadingInitialData`)

### Demo mode

- [x] Sandbox `Load demo data` so dummy UUIDs (Maya / Jordan / Alex) can't FK-violate against Supabase. `AppState.isInDemoMode` flag gates every CRUD method's server-sync `Task`; local mutations still apply.
- [x] `exitDemoMode()` re-runs `bootstrapUserSession` so real `currentUserID` + household + data restore from the server in one tap.
- [x] `Components/DemoModeBanner` pinned to the top of the tab body via a VStack row in `RootTabView` (avoids nested `safeAreaInset(.top)` overlap with tabs that have their own title insets).

### Sign-in screen

- [x] Card-less redesign matching the onboarding mock — large centered ORTHO wordmark over the screen background, form pinned to the bottom safe area, muted-fill input + button + per-step fine-print footer (Terms/Privacy on email, "Send again" on code).
- [x] Title typography rebalanced — "Sign in" / "Enter your code" at 24pt bold so they don't outweigh the wider-tracked ORTHO wordmark above.
- [x] Placeholder text styled via the modern `prompt: Text(...).foregroundStyle(...)` API to override the system-blue tint with neutral 36%-opacity gray.
- [x] OTP length aligned to the Supabase project — placeholder shows 8 dots, Verify enabled at 8 digits entered.
- [x] `Components/AmbientRippleBackground` — concentric stroke rings + soft accent-tinted lens-flare halo emanating from inside the first O of "ORTHO". `TimelineView` + `Canvas` for one GPU-friendly pass per frame.

### Later / nice-to-have

- [ ] In-app invitation banner via Realtime subscription (for users already signed in)
- [ ] Manual short-code entry as a third invitation channel
- [ ] Realtime subscriptions for multi-device sync of household data
- [ ] Push notifications (requires paid Apple Developer Program — $99/year)
- [ ] Sign in with Apple (requires paid Apple Developer Program)
- [ ] Move FX rate fetch to a scheduled Edge Function (replace inline floatrates.com fetch from iOS)
- [ ] Revisit SwiftData if offline-first or local querying becomes a real requirement
- [ ] Update `ARCHITECTURE.md` — Dashboard section is stale (widget-based now, not placeholder)

---

## Done

- [x] **2026-05-21** — Decision: Supabase is the backend (no separate API server needed)
- [x] **2026-05-21** — Decision: magic-link auth (defer Sign in with Apple until paid Apple Dev Program)
- [x] **2026-05-21** — Decision: unified user identity (`User.id` = `auth.uid()`)
- [x] **2026-05-21** — Decision: optimistic updates with rollback
- [x] **2026-05-21** — Decision: JSON-on-disk cache for v1; SwiftData later if needed
- [x] **2026-05-21** — Decision: Adopted Identity & Permissions Model spec (see Spec section). Supersedes earlier sketch — local users are device-only, roles are `owner / admin / member`, `transaction_shares` (Ortho users only) replaces the earlier `transaction_owners` idea.
- [x] **2026-05-21** — Created Supabase project `brujhxmtzfgowimprueo`. Project URL + publishable key captured in gitignored `Ortho-iOS/Ortho-iOS/App/SupabaseConfig.swift` (template committed alongside).
- [x] **2026-05-21** — Added `.gitignore` (Xcode artifacts, secrets, env files). Replaces having none. Note: previously-committed `xcuserdata` files remain in history and need an explicit `git rm --cached` to untrack.
- [x] **2026-05-21** — Customized magic-link email template (branded HTML, "Sign in to Ortho" CTA, fallback URL block). Saved in Supabase dashboard.
- [x] **2026-05-21** — Added `supabase-swift` SPM dependency via direct `project.pbxproj` edits (resolved to v2.46.0). Debug build for iOS Simulator succeeded; package links and codesigns cleanly.
- [x] **2026-05-21** — Wired Supabase client + auth state into `AppState` (session, isAuthLoading, authError, pendingSignInEmail) with methods `requestSignInCode`, `verifyCode`, `signOut`, `resetSignInFlow`, `observeAuthChanges`.
- [x] **2026-05-21** — Built `Features/Auth/SignInView.swift` — two-step OTP flow (email → 6-digit code) with brand styling.
- [x] **2026-05-21** — Gated `RootTabView` behind `appState.session` in `Ortho_iOSApp`. The `.task` modifier subscribes to `observeAuthChanges()` which doubles as launch-time session restore.
- [x] **2026-05-21** — Magic-link email template updated to render `{{ .Token }}` as a big monospaced block — the iOS app uses the OTP code, not the link.
- [x] **2026-05-21** — `SignInView` OTP input accepts 6-8 digits (Supabase project is currently set to 8). Verify enables at ≥6 digits; server rejects wrong-length codes.
- [x] **2026-05-21** — **Auth working end-to-end.** Sign-in via email magic-link OTP, session persisted via SDK keychain, launch restore via `authStateChanges` `INITIAL_SESSION` event.
- [x] **2026-05-21** — Decision: v1 ships with `owner / member` roles only. Admin role deferred — easy add later (enum case + new policy clauses, no schema migration).
- [x] **2026-05-21** — Decision: v1 invitation channels are magic-link OTP email + QR code (matches spec). In-app banner and manual short-code entry move to "Later."
- [x] **2026-05-21** — Untracked `xcuserdata` via `git rm --cached`. Future scheme reorders won't dirty `git status`.
- [x] **2026-05-21** — Added "Account" section to `SettingsView` with a Sign out row (shows current email, destructive confirmation alert, calls `appState.signOut()`).
- [x] **2026-05-21** — `AppState.ensureCurrentUser(authID:email:)` syncs `currentUserID` to `session.user.id` on auth-state change. Creates a User row + adds them to the active household if missing. Email is exposed via `AppState.currentUserEmail` so view code doesn't need to `import Auth`.
- [x] **2026-05-21** — Configured Resend SMTP in Supabase (`smtp.resend.com:465`, sender `onboarding@resend.dev`). Replaces built-in auth email service — no more per-project rate limits during testing. Test sign-in email landed successfully.
- [x] **2026-05-21** — Drafted initial Postgres schema at `supabase/migrations/20260521120000_initial_schema.sql` — 12 tables, 5 enums (`role`, `transaction_kind`, `transaction_scope`, `property_kind`, `transaction_category`), CHECK constraints, indexes, `updated_at` trigger, RLS on every table with security-definer membership helpers, `accept_invite(token)` RPC. Not yet applied to Supabase.
- [x] **2026-05-21** — Swift model updates to match the schema. New: `Role`, `TransactionScope`, `HouseholdMember`, `PendingInvite`, `LocalUser`. Updated: `User` (Codable), `Transaction` (`+scope`, `+createdBy`, Codable, snake_case CodingKeys), `Card` (`+householdID`, Codable), `Property` (`+householdID`). Unified the sheet-local `TransactionScopeMode` enum into the new shared `TransactionScope`. Build verified clean.
- [x] **2026-05-21** — Supabase CLI installed (direct binary download — Homebrew formula needs newer Command Line Tools than this Mac has) at `/opt/homebrew/bin/supabase` + `supabase-go`. `supabase init` ran in repo root (`config.toml`, `project_id = "Ortho-iOS"`), `supabase login` + `supabase link --project-ref brujhxmtzfgowimprueo` completed.
- [x] **2026-05-21** — Initial schema applied to remote Supabase via `supabase db push`. All 12 tables, 5 enums, RLS policies, helpers, and `accept_invite` RPC are now live on project `brujhxmtzfgowimprueo`.
- [x] **2026-05-21** — Data-layer migration **phase 1: transactions only**. Added `Services/` folder with `SupabaseAPI.swift` (`SupabaseAPIError`, date strategies) and `TransactionsAPI.swift` (fetch/create/update/delete with `TransactionRecord` + `TransactionShareRow` DTOs). `AppState.addTransaction/updateTransaction/deleteTransaction` are now optimistic-with-rollback against the server. New `loadTransactionsFromServer()` triggered manually from the Developer section ("Sync from server" row).
- [x] **2026-05-21** — Auth bootstrap added. First sign-in now (1) upserts the `public.users` row so the `transactions.created_by` FK resolves, (2) finds or creates a default "Home" household + a `household_members` row with `role = 'owner'`, and (3) wipes the in-memory sample data (Maya / Jordan / Home seed UUIDs that never existed on the server). Without this, every insert FK-failed and rolled back — added rows "vanished after a beat."
- [x] **2026-05-21** — **Transaction round-trip verified end-to-end.** Added a shared transaction in the app → `transactions` + `transaction_shares` row counts went 0 → 1 on the server → `loadTransactionsFromServer()` returned it intact, identical in the UI. Encode / RLS / decode all green.
- [x] **2026-05-21** — Full data-layer migration shipped: `CardsAPI` + `PropertiesAPI` (coordinates 4 tables — properties / mortgage_info / lease_info / units, dates as `yyyy-MM-dd` strings) + `RentalPaymentsAPI` + `HouseholdsAPI` (extracts the inline bootstrap DTOs and adds rename + remove-member). Every `AppState` CRUD method now optimistic + server-synced with rollback. New `loadAllFromServer()` parallel-fetcher used by both bootstrap and the renamed "Sync all from server" Developer affordance. Add-member is disabled in `HouseholdView` pending the Invitations flow.
- [x] **2026-05-21** — Audit + fix of mortgage / multifamily financials: amortization formula verified end-to-end against canonical $530k/6.85%/30yr example. Two correctness bugs fixed: zero-interest mortgages now use flat amortization (was returning 0 monthly payment); `MultifamilyNetBalanceCard` no longer counts vacant units as collected rent (math moved onto `Property` as `occupiedMonthlyRentCents` / `netMonthlyBalanceCents`).
- [x] **2026-05-21** — **Budgets + rule-based recommendation engine** (merged via PR #1). New `public.budgets` table + `BudgetsAPI`; per-category monthly limits set/edited in `Features/Budgets/BudgetsView`. `Services/InsightEngine.swift` is a pure-functions namespace with 8 rules (top category, MoM category delta, budget status, cashflow/savings rate, recurring subscription detection, outlier transactions, daily trend, mortgage affordability) returning prioritized `Insight` values. Dashboard gets `InsightsCardStack` at the top and `BudgetProgressCard` under the month summary; both hide themselves on empty.
- [x] **2026-05-21** — Transactions tab: renamed header "Activity" → "Transactions" and added a Housing-style empty state when the array is empty.
- [x] **2026-05-21** — Multi-add + Copy-from-recent in `AddTransactionSheet`. "Save and add another" capsule below the form resets the transaction-specific fields and keeps the contextual ones. "Copy from recent" pill at the top opens `CopyTransactionPickerSheet` (40 most-recent txs grouped by day) and pre-fills every field via the same `copying:` init path the swipe-copy gesture uses. Closure signature is `(Transaction, keepOpen: Bool) -> Void`.
- [x] **2026-05-21** — `CopyTransactionPickerSheet` rows were unresponsive — `TransactionRow` is itself a Button and nested-Button hit testing in SwiftUI was eating taps. Fixed by passing the pick callback as `TransactionRow.onTap` directly (matches the main TransactionsView pattern); no more wrapper Button or `.allowsHitTesting` hack.
- [x] **2026-05-21** — Loading skeleton on the Transactions tab during initial bootstrap. New `isLoadingInitialData` flag on AppState (set/cleared inside `bootstrapUserSession`); `TransactionsView` switches on a `LoadState` enum (`.loading` → `TransactionSkeletonList`, `.empty` → existing empty state, `.populated` → real list). Prevents the misleading "No transactions yet" flash during sign-in.
- [x] **2026-05-21** — Swipe-copy on transaction rows. `SwipeActionRow` gains an optional `onCopy` closure — when set, the revealed tray doubles in width and shows `[Copy] [Delete]` (Copy accent, Delete destructive, Delete remains rightmost per iOS Mail convention). Add-sheet presentation in `TransactionsView` unified behind an `AddSheetMode` enum (`.fresh` / `.copying(Transaction)`) driving a single `.sheet(item:)` modifier.
- [x] **2026-05-21** — Sandboxed `Load demo data`. New `AppState.isInDemoMode` flag set by `loadDummyData()` makes every server-syncing CRUD method (14 total — transactions / cards / properties / rental payments / budgets / household rename + member removal) `guard !isInDemoMode else { return }` before its background Task. `exitDemoMode()` clears the flag, resets `bootstrappedAuthID`, re-runs `bootstrapUserSession` so real auth data restores. `Components/DemoModeBanner` in a VStack row above the tab body in `RootTabView` (DEBUG only). Settings copy updated to explain the local-only semantics.
- [x] **2026-05-21** — Sign-in screen redesign to the card-less mock: large centered ORTHO wordmark over the screen bg, form pinned to the bottom safe area, muted-fill input + button, per-step fine-print footer ("Terms / Privacy" on email, "Didn't receive it? Send again" on code wired to `requestSignInCode`). Title typography rebalanced to 24pt bold so it doesn't outweigh the wider-tracked wordmark. Placeholders styled via `prompt: Text(...).foregroundStyle(...)` to override the system-blue tint. OTP length is 8 across placeholder + Verify enable threshold.
- [x] **2026-05-21** — `Components/AmbientRippleBackground` added to the sign-in screen. Concentric stroke rings expanding from a configurable origin (UnitPoint + absolute CGSize nudge) over a soft accent-tinted radial-gradient lens-flare halo. `TimelineView` + `Canvas` for one render pass per frame. Origin offset to `(-50, 0)` so ripples emanate from inside the first O of "ORTHO". Both rings and flare share `AppTheme.accent` so the effect reads as warm light from a single source.

---

## Decisions (architectural reference)

Locked-in choices that shape downstream work. Don't re-open without flagging.

- **Backend** — Supabase (Postgres + Auth + Realtime + Edge Functions). No custom server.
- **Auth** — Email magic link via Supabase. Sign in with Apple deferred to paid Apple Dev Program era.
- **Identity** — Unified: `User.id` = `auth.uid()`. A real Ortho user is one row in `users` keyed by their Supabase auth UUID.
- **Local users** — Device-only. Stored in the JSON cache, never written to the backend. Used for personal-scope splits with non-app people only.
- **Roles (v1)** — `owner / member` only. Admin role deferred; will land as an additional enum case + new policy branches when needed.
- **Money** — `Int64` USD cents internally; convert to display currency at render time. Unchanged.
- **State store** — Single `@Observable` `AppState`; reads via `@Environment`. Unchanged.
- **Update model** — Optimistic with rollback.
- **Cache** — JSON-on-disk via Codable for v1. Reconsider SwiftData when offline-first becomes a real requirement.
- **Transaction ownership** — Shared transactions: `transaction_shares` rows reference `user_id` (Ortho users only). Personal transactions: owner is implicit (`created_by`); any local-user splits stay device-only.

---

## Spec — Identity & Permissions Model

How households, members, and shared financial data are modeled and protected
using Supabase (Postgres + Row-Level Security). Covers the primary user,
Ortho users, and local device-only users, and how permissions apply to shared
expenses and income.

### Identity types

- **Primary user** — household owner, authenticated via Supabase Auth. Always exists in the backend.
- **Ortho app user** — an authenticated Supabase user who can join shared households.
- **Local user** — device-only identity stored in client storage. *Not* treated as an authoritative shared member in the backend. Use local users only for personal / device-local splits. For shared households, require Ortho users for consistent syncing.

### Data model (tables)

| Table | Fields |
|---|---|
| `households` | `id`, `owner_id`, `name`, `created_at` |
| `household_members` | `household_id`, `user_id`, `role` (`owner` \| `admin` \| `member`), `created_at` |
| `pending_invites` | `id`, `household_id`, `email` (nullable), `role`, `token_hash`, `expires_at`, `created_by` |
| `transactions` | `id`, `household_id`, `amount_cents`, `kind` (`expense` \| `income`), `scope` (`personal` \| `shared`), `created_by`, `created_at`, `updated_at` |
| `transaction_shares` | `transaction_id`, `user_id`, `percent`. **Ortho users only** — local splits stay on the device. |

### Roles and permissions

- **Owner** — manages membership, household settings, any transaction.
- **Admin** — manages shared transactions and (optionally) membership.
- **Member** — can insert shared transactions; can update or delete only those they created.
- **Local user** — not an authoritative member. Data is personal / device-local and grants no backend permissions.

### Supabase RLS (conceptual)

- `SELECT` — allowed for members of the household.
- `INSERT` — allowed for members on shared transactions.
- `UPDATE` / `DELETE` — allowed if `created_by = auth.uid()` OR the user has `admin` or `owner` role in that household.

### Invite + confirmation flows

- **Magic link with one-time passcode** — create a `pending_invites` row, send a Supabase Auth OTP/magic-link email, on authentication redeem the token via an RPC function (`accept_invite`).
- **QR** — generate a one-time token, encode it in a QR; recipient scans, signs in, redeems.

### Edge cases

- When a member is removed, keep historical transactions but block new inserts by that user.
- Always store `created_by` and `updated_at` for auditing.

### Offline and local behavior

- Personal transactions and local-user splits stay on the device.
- Shared transactions sync only with authoritative Ortho-user shares. Local-only details must not be required for backend consistency.
