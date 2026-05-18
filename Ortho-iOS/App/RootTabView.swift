import SwiftUI

enum OrthoTab: String, CaseIterable, Hashable, Identifiable {
    case dashboard, transactions, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:    "Dashboard"
        case .transactions: "Transactions"
        case .settings:     "Settings"
        }
    }

    /// SF Symbol for the tab. Outlined; selected state communicated by color.
    var symbol: String {
        switch self {
        case .dashboard:    "house"
        case .transactions: "arrow.up.arrow.down"
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
        .background(.ultraThinMaterial)
        .background(AppTheme.bg.opacity(0.86))
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

    var body: some View {
        ZStack {
            switch selection {
            case .dashboard:
                DashboardView()
            case .transactions:
                TransactionsView()
            case .settings:
                SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OrthoTabBar(selection: $selection)
        }
        .background(AppTheme.bg.ignoresSafeArea())
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
