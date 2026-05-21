# Ortho — Tasks

Lightweight Kanban for backend integration and other in-flight work. Move
items between sections as they progress. Date the entry when you start or
finish so the history is preserved.

---

## In progress

_(none — sign-out + currentUserID landed; auth chapter is complete)_

---

## To do

### Setup

- [ ] Set up Supabase CLI locally (`supabase login`, `supabase init`, `supabase link --project-ref brujhxmtzfgowimprueo`) — needed when we start writing SQL migrations
- [ ] Set up Resend SMTP integration in Supabase (replaces built-in email service; sidesteps rate limits during schema/RLS testing)

### Schema (Postgres — see Spec section below)

- [ ] Draft schema: `households`, `household_members`, `pending_invites`, `transactions`, `transaction_shares`, plus the existing housing tables (`properties`, `mortgage_info`, `lease_info`, `units`, `rental_payments`) and `cards`
- [ ] Define enums: `role` (`owner | member` for v1; `admin` deferred), `kind` (`expense | income`), `scope` (`personal | shared`)
- [ ] Add CHECK constraints (e.g. `amount_cents >= 0`, `(scope = 'shared') = (household_id IS NOT NULL)`)
- [ ] Write RLS policies per table (see RLS sketch in Spec)
- [ ] Write `accept_invite(token)` RPC function (validates `token_hash`, expiry, then inserts `household_members` row + marks invite redeemed)
- [ ] Run schema SQL against Supabase

### Swift models

- [ ] Add `HouseholdMember` model (with `role` field)
- [ ] Add `PendingInvite` model
- [ ] Add `LocalUser` model (device-only; persisted in JSON cache, never sent to backend)
- [ ] Rename `Transaction.ownerIDs` semantics: for shared transactions, IDs are `User.ID` (= `auth.uid()`) of Ortho users only. Local-user owners only appear on personal-scope transactions and stay on device.
- [ ] Add `Transaction.scope` (`personal | shared`) and `Transaction.createdBy: User.ID`
- [ ] Make `User` Codable (match schema)
- [ ] Make `Transaction` Codable
- [ ] Cross-check existing Codable models against schema: `Property`, `Household`, `MortgageInfo`, `LeaseInfo`, `Unit`, `RentalPayment`, `Currency`

### Auth

- [x] Build sign-in screen (email → 6-digit OTP code → session)
- [x] Gate `RootTabView` behind auth state via `appState.session`
- [x] Auth-state observer (`observeAuthChanges`) restores session on launch + tracks sign-in/out
- [x] Sign-out UI in Settings (Account section + destructive confirmation alert)
- [x] `currentUserID` now driven by `session.user.id` via `ensureCurrentUser`; new auth users are seeded into `users` and the active household automatically
- [ ] Magic-link deep-link flow (`ortho://auth-callback` URL scheme) — later polish; OTP code works without it

### Data layer

- [ ] Thin API client wrapper around `supabase-swift`
- [ ] Migrate `AppState.transactions` CRUD to Supabase (respecting RLS / `created_by`)
- [ ] Migrate `AppState.properties` CRUD
- [ ] Migrate `AppState.rentalPayments` CRUD
- [ ] Migrate `AppState.cards` CRUD
- [ ] Migrate household + member management (creates, role checks, member removal preserves history)
- [ ] Optimistic update plumbing with rollback-on-failure

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
