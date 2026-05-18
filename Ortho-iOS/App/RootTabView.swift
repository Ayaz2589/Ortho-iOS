import SwiftUI

/// Set by pushed detail views that want the custom `OrthoTabBar` to slide
/// away (e.g. property detail, household editor). `RootTabView` reads the
/// aggregated value via `.onPreferenceChange` and toggles the bar's
/// `safeAreaInset` content.
struct HideTabBarPreferenceKey: PreferenceKey {
    static let defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        // OR-fold: any child that requests hiding wins.
        value = value || nextValue()
    }
}

extension View {
    /// Hide the global tab bar while this view is on-screen. Use on pushed
    /// detail screens that want the full vertical canvas.
    func hidesTabBar(_ hide: Bool = true) -> some View {
        preference(key: HideTabBarPreferenceKey.self, value: hide)
    }
}

enum OrthoTab: String, CaseIterable, Hashable, Identifiable {
    case dashboard, transactions, housing, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:    "Dashboard"
        case .transactions: "Transactions"
        case .housing:      "Housing"
        case .settings:     "Settings"
        }
    }

    /// SF Symbol for the tab. Outlined; selected state communicated by color.
    var symbol: String {
        switch self {
        case .dashboard:    "chart.bar"
        case .transactions: "arrow.up.arrow.down"
        case .housing:      "house"
        case .settings:     "gearshape"
        }
    }
}

/// Classic-iOS tab bar (option B from the design canvas). Flat surface with a
/// hairline above; icon + small label per tab.
struct OrthoTabBar: View {
    @Binding var selection: OrthoTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OrthoTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(alignment: .top) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        // Frosted-glass blur — scrolling content shows through, faintly
        // softened. `.ultraThinMaterial` adapts to light/dark on its own,
        // so no warm-bg overlay is needed underneath.
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func tabButton(_ tab: OrthoTab) -> some View {
        let isActive = tab == selection
        Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 22, weight: .regular))
                    .frame(height: 26)
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .kerning(0.1)
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? AppTheme.text : AppTheme.text3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

/// App shell. Owns tab selection; swaps body between Dashboard, Transactions,
/// and Settings. Reserves room for the bar via `safeAreaInset(.bottom)`.
struct RootTabView: View {
    @State private var selection: OrthoTab = .transactions
    @State private var tabBarHidden: Bool = false
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            switch selection {
            case .dashboard:
                DashboardView()
            case .transactions:
                TransactionsView()
            case .housing:
                HousingView()
            case .settings:
                SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !tabBarHidden {
                OrthoTabBar(selection: $selection)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onPreferenceChange(HideTabBarPreferenceKey.self) { newValue in
            withAnimation(.easeOut(duration: 0.22)) {
                tabBarHidden = newValue
            }
        }
        .task {
            // Fetch live FX rates once per app launch when cache is stale.
            await appState.refreshRatesIfStale()
        }
    }
}

#Preview("Root · Light") {
    RootTabView()
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Root · Dark") {
    RootTabView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
