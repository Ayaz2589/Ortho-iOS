import SwiftUI

/// Modal sheet for adding a transaction (expense or income).
///
/// Design grammar matches AddUserSheet: Cancel · "New transaction" · Add,
/// plain-text actions, Add disabled until valid. The amount is the headline
/// (40pt tabular numerals, leading "$"); direction is a custom segmented
/// control. Owner picker is multi-select — a joint transaction means selecting
/// two (or more) household members, matching `Transaction.ownerIDs: Set<...>`.
struct AddTransactionSheet: View {
    let onAdd: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var kind: TransactionKind = .expense
    @State private var amountText: String = ""
    @State private var merchant: String = ""
    @State private var category: TransactionCategory = .groceries
    @State private var selectedOwners: Set<User.ID> = []
    /// Per-owner split percentage as user-typed strings. Parsed at submit time.
    /// Only meaningful when `showsSplit` is true.
    @State private var splitPercents: [User.ID: String] = [:]
    @State private var source: String = "Amex Gold"
    @State private var date: Date = .now

    @FocusState private var amountFocused: Bool

    /// 0.5% tolerance so display rounding (e.g. 33.33 + 33.33 + 33.34 = 100)
    /// doesn't block submission.
    private static let splitTolerance: Decimal = 0.5

    private static let expenseSources: [String] = [
        "Amex Gold", "Chase Sapphire", "Apple Card", "ACH · Joint",
    ]
    private static let incomeSources: [String] = [
        "ACH · Checking", "ACH · Joint", "Wire",
    ]

    /// Non-negative amount parsed from the text field; `nil` if empty or 0.
    private var parsedAmount: Decimal? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let d = Decimal(string: cleaned), d > 0 else { return nil }
        return d
    }

    private var canAdd: Bool {
        parsedAmount != nil
        && !merchant.trimmingCharacters(in: .whitespaces).isEmpty
        && !selectedOwners.isEmpty
        && (!showsSplit || splitIsValid)
    }

    /// Show split editor only on multi-owner expenses. Income with multiple
    /// owners stays equal-split per the footer caption.
    private var showsSplit: Bool {
        kind == .expense && selectedOwners.count >= 2
    }

    /// Parsed [User.ID: Decimal] of the current splitPercents map, restricted
    /// to currently-selected owners.
    private var parsedSplits: [User.ID: Decimal] {
        var out: [User.ID: Decimal] = [:]
        for id in selectedOwners {
            let raw = (splitPercents[id] ?? "").trimmingCharacters(in: .whitespaces)
            out[id] = Decimal(string: raw) ?? 0
        }
        return out
    }

    private var splitTotal: Decimal {
        parsedSplits.values.reduce(0, +)
    }

    private var splitIsValid: Bool {
        let diff = splitTotal - 100
        let abs = diff >= 0 ? diff : -diff
        return abs <= Self.splitTolerance
    }

    private var merchantLabel: String { kind == .income ? "Source" : "Merchant" }
    private var sourceLabel:   String { kind == .income ? "Deposit to" : "Paid with" }
    private var sources:       [String] { kind == .income ? Self.incomeSources : Self.expenseSources }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetNav

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    amountHero
                    directionToggle

                    formGroup {
                        textRow(
                            label: merchantLabel,
                            placeholder: kind == .income ? "e.g. Acme Co. payroll" : "e.g. Whole Foods",
                            text: $merchant
                        )
                        if kind == .expense {
                            divider
                            categoryRow
                        }
                    }

                    formGroup {
                        ownerRow
                        divider
                        sourceRow
                        divider
                        dateRow
                    }

                    if showsSplit {
                        splitSection
                    }

                    Text(kind == .income
                         ? "Income shows in sage on the Activity list. Selecting multiple owners attributes shared income to all of them."
                         : "Selecting multiple owners marks the transaction as shared.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 360, alignment: .leading)
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppTheme.bg)
        .onAppear {
            // Default the owner to the first household member if nothing's set.
            if selectedOwners.isEmpty, let first = appState.users.first {
                selectedOwners = [first.id]
            }
            resetSplitsToEven()
            // Delay focus so sheet finishes presenting before the keyboard rises.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                amountFocused = true
            }
        }
        .onChange(of: kind) { _, _ in
            // Keep the source valid when direction flips.
            if !sources.contains(source) { source = sources.first ?? "" }
            resetSplitsToEven()
        }
        .onChange(of: selectedOwners) { _, _ in
            resetSplitsToEven()
        }
    }

    // MARK: - Sheet nav

    private var sheetNav: some View {
        ZStack {
            Text("New transaction")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .tracking(-0.3)

            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
                Spacer()
                Button("Add") {
                    guard let amount = parsedAmount else { return }
                    let tx = Transaction(
                        merchant: merchant.trimmingCharacters(in: .whitespaces),
                        category: kind == .income ? .income : category,
                        kind: kind,
                        amount: amount,
                        ownerIDs: selectedOwners,
                        splits: showsSplit ? parsedSplits : nil,
                        source: source,
                        date: date
                    )
                    onAdd(tx)
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(canAdd ? AppTheme.accent : AppTheme.text.opacity(0.36))
                .disabled(!canAdd)
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.12), value: canAdd)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Amount hero

    private var amountHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Spacer()
            Text("$")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(amountText.isEmpty
                                 ? AppTheme.text.opacity(0.36)
                                 : (kind == .income ? AppTheme.positive : AppTheme.text))
                .tracking(-0.4)

            TextField("0.00", text: $amountText)
                .font(.system(size: 40, weight: .semibold))
                .tracking(-0.6)
                .monospacedDigit()
                .foregroundStyle(kind == .income ? AppTheme.positive : AppTheme.text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
                .fixedSize()
                .focused($amountFocused)
            Spacer()
        }
        .padding(.vertical, 8)
        .animation(.easeOut(duration: 0.12), value: kind)
    }

    // MARK: - Direction toggle

    private var directionToggle: some View {
        HStack(spacing: 4) {
            ForEach(TransactionKind.allCases, id: \.self) { k in
                Button {
                    kind = k
                } label: {
                    Text(k == .income ? "Income" : "Expense")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.1)
                        .foregroundStyle(kind == k ? AppTheme.text : AppTheme.text.opacity(0.58))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(kind == k ? AppTheme.surface : .clear)
                                .shadow(color: kind == k ? .black.opacity(0.06) : .clear,
                                        radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.text.opacity(0.05))
        )
        .padding(.horizontal, 16)
        .animation(.easeOut(duration: 0.15), value: kind)
    }

    // MARK: - Field rows

    @ViewBuilder
    private func formGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.hairline)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func textRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text.opacity(0.58))
                .frame(width: 96, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: 17, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    /// Multi-select owner row — chips toggle membership in `selectedOwners`.
    /// Horizontally scrollable so it stays a single line as the household
    /// grows past 3-4 members.
    private var ownerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Owners")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text.opacity(0.58))
                .frame(width: 96, alignment: .leading)
                .padding(.top, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(appState.users) { u in
                        OwnerChipView(
                            user: u,
                            selected: selectedOwners.contains(u.id),
                            onTap: { toggle(u.id) }
                        )
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private func toggle(_ id: User.ID) {
        if selectedOwners.contains(id) {
            // Keep at least one owner — chips can deselect down to one.
            if selectedOwners.count > 1 { selectedOwners.remove(id) }
        } else {
            selectedOwners.insert(id)
        }
    }

    private var categoryRow: some View {
        HStack(spacing: 12) {
            Text("Category")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text.opacity(0.58))
                .frame(width: 96, alignment: .leading)
            Spacer()
            Menu {
                ForEach(TransactionCategory.allCases.filter { $0 != .income }, id: \.self) { c in
                    Button(c.rawValue.capitalized) { category = c }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 13, weight: .semibold))
                    Text(category.rawValue.capitalized)
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.2)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                }
                .foregroundStyle(AppTheme.text)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private var sourceRow: some View {
        HStack(spacing: 12) {
            Text(sourceLabel)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text.opacity(0.58))
                .frame(width: 96, alignment: .leading)
            Spacer()
            Menu {
                ForEach(sources, id: \.self) { s in
                    Button(s) { source = s }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(source)
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.2)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.text.opacity(0.36))
                }
                .foregroundStyle(AppTheme.text)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private var dateRow: some View {
        HStack(spacing: 12) {
            Text("Date")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text.opacity(0.58))
                .frame(width: 96, alignment: .leading)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AppTheme.accent)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    // MARK: - Split section

    /// Visible only for multi-owner expenses. One row per selected owner with
    /// an editable percentage; the live total turns sage when it equals 100
    /// and the Add button is gated on the same condition.
    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Split")
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.text.opacity(0.58))
                Spacer()
                Button("Even", action: resetSplitsToEven)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            let owners = sortedSelectedOwners
            formGroup {
                ForEach(Array(owners.enumerated()), id: \.element.id) { idx, u in
                    splitRow(for: u)
                    if idx < owners.count - 1 { divider }
                }
                divider
                splitTotalRow
            }
        }
    }

    private var sortedSelectedOwners: [User] {
        appState.users
            .filter { selectedOwners.contains($0.id) }
    }

    private func splitRow(for u: User) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(user: u, size: 24)
            Text(u.name)
                .font(.system(size: 17, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(AppTheme.text)
            Spacer()
            TextField("0", text: splitBinding(for: u.id))
                .font(.system(size: 17, weight: .medium))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 64)
                .foregroundStyle(AppTheme.text)
            Text("%")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text.opacity(0.58))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    /// Binding that writes the user-typed string verbatim, then rebalances the
    /// other owners so the total stays at 100. The edited owner's string is
    /// never reformatted mid-typing — so "0.0" doesn't get clobbered into
    /// "0.00" while you're still typing the trailing digit.
    private func splitBinding(for id: User.ID) -> Binding<String> {
        Binding(
            get: { splitPercents[id] ?? "" },
            set: { newValue in
                splitPercents[id] = newValue
                rebalance(after: id)
            }
        )
    }

    private var splitTotalRow: some View {
        HStack(spacing: 12) {
            Text("Total")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text.opacity(0.58))
            Spacer()
            Text(formatPercent(splitTotal))
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(splitIsValid ? AppTheme.positive : AppTheme.text.opacity(0.58))
            Text("%")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text.opacity(0.58))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .animation(.easeOut(duration: 0.12), value: splitIsValid)
    }

    // MARK: - Split helpers

    /// Reset splitPercents to an even distribution across `selectedOwners`.
    /// The last owner absorbs any rounding remainder so the total is exactly
    /// 100 in the common 3-owner case (33.33 + 33.33 + 33.34).
    private func resetSplitsToEven() {
        let owners = sortedSelectedOwners
        guard !owners.isEmpty else {
            splitPercents = [:]
            return
        }
        let count = owners.count
        let baseTwoDigit = (100.0 / Double(count) * 100).rounded(.down) / 100  // e.g. 33.33
        var totals = Array(repeating: baseTwoDigit, count: count)
        let remainder = 100.0 - baseTwoDigit * Double(count)
        totals[count - 1] += (remainder * 100).rounded() / 100

        var next: [User.ID: String] = [:]
        for (i, u) in owners.enumerated() {
            next[u.id] = String(format: "%.2f", totals[i])
        }
        splitPercents = next
    }

    private func formatPercent(_ d: Decimal) -> String {
        let ns = NSDecimalNumber(decimal: d)
        return String(format: "%.2f", ns.doubleValue)
    }

    /// Distributes the remaining percentage (100 - editedValue) across the
    /// *other* owners. If those owners already have values, the remainder is
    /// split proportionally to their existing weights — so prior manual
    /// adjustments survive subsequent edits. If they're all zero, falls back
    /// to even distribution.
    private func rebalance(after edited: User.ID) {
        let others = sortedSelectedOwners.filter { $0.id != edited }
        guard !others.isEmpty else { return }

        let editedRaw = (splitPercents[edited] ?? "").trimmingCharacters(in: .whitespaces)
        let editedParsed = Decimal(string: editedRaw) ?? 0
        let editedClamped = max(0, min(100, editedParsed))
        let remaining = max(0, 100 - editedClamped)

        let currentValues: [Decimal] = others.map { u in
            let raw = (splitPercents[u.id] ?? "").trimmingCharacters(in: .whitespaces)
            return Decimal(string: raw) ?? 0
        }
        let currentSum = currentValues.reduce(0, +)

        let rawNew: [Decimal]
        if currentSum > 0 {
            rawNew = currentValues.map { ($0 / currentSum) * remaining }
        } else {
            let per = remaining / Decimal(others.count)
            rawNew = Array(repeating: per, count: others.count)
        }

        // Round each to 2dp; absorb rounding error in the last entry so the
        // displayed total is exactly 100 (within representable precision).
        var rounded: [Decimal] = []
        for (i, v) in rawNew.enumerated() {
            if i < rawNew.count - 1 {
                rounded.append(roundedToTwoDecimals(v))
            } else {
                let sumSoFar = rounded.reduce(Decimal(0), +)
                rounded.append(remaining - sumSoFar)
            }
        }

        for (u, v) in zip(others, rounded) {
            splitPercents[u.id] = formatPercent(v)
        }
    }

    private func roundedToTwoDecimals(_ d: Decimal) -> Decimal {
        var src = d
        var dst = Decimal()
        NSDecimalRound(&dst, &src, 2, .plain)
        return dst
    }
}

// MARK: - Owner chip

/// Pill chip with the user's avatar + name. Selected state is a 1.5pt outline
/// in `AppTheme.text` and a slightly stronger background — no brand-color
/// fill swap.
private struct OwnerChipView: View {
    let user: User
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                UserAvatarView(user: user, size: 22)
                Text(user.name)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.1)
                    .foregroundStyle(AppTheme.text)
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AppTheme.text.opacity(selected ? 0.06 : 0.03))
            )
            .overlay(
                Capsule()
                    .strokeBorder(selected ? AppTheme.text : .clear, lineWidth: 1.5)
            )
            .animation(.easeOut(duration: 0.12), value: selected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Add Transaction · Light") {
    Color.gray.opacity(0.2)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            AddTransactionSheet { _ in }
                .environment(AppState())
                .presentationBackground(AppTheme.bg)
        }
}

#Preview("Add Transaction · Dark") {
    Color.gray.opacity(0.2)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            AddTransactionSheet { _ in }
                .environment(AppState())
                .presentationBackground(AppTheme.bg)
        }
        .preferredColorScheme(.dark)
}
