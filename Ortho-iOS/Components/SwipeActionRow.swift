import SwiftUI

/// iOS-style swipe-to-delete wrapper. Place around any row; horizontal
/// drags reveal a destructive Delete action on the trailing edge.
/// Stationary taps fall through to any Button inside `content` (the
/// `DragGesture` has a `minimumDistance` threshold), so primary tap
/// behavior is preserved.
///
/// When the row is open, an invisible tap-to-close overlay sits on top of
/// the slid content. Tapping anywhere on the content (other than the
/// revealed Delete button) snaps the swipe closed.
struct SwipeActionRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    private let revealWidth: CGFloat = 84

    @State private var offset: CGFloat = 0
    /// Position the content has settled at between drags (0 = closed,
    /// -revealWidth = fully open). New drags start from here.
    @State private var anchor: CGFloat = 0

    private var isOpen: Bool { offset < -1 }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Underlying destructive action — covered by `content` until
            // the user swipes left.
            Button {
                triggerDelete()
            } label: {
                Text("Delete")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: revealWidth)
                    .frame(maxHeight: .infinity)
                    .background(AppTheme.destructive)
            }
            .buttonStyle(.plain)

            // Foreground content slides over the button.
            content()
                .background(AppTheme.surface)
                .offset(x: offset)
                .overlay {
                    // Only attach the tap-to-close gesture while open —
                    // otherwise stationary taps would be swallowed before
                    // they could reach the row's own onTap (drill-in).
                    if isOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { closeSwipe() }
                    }
                }
                .gesture(swipeGesture)
        }
    }

    // MARK: - Behavior

    private func triggerDelete() {
        // Slide the row fully off-screen, then notify the parent. The
        // parent removes from data, SwiftUI's diff handles the layout fall.
        withAnimation(.easeIn(duration: 0.2)) {
            offset = -1000
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onDelete()
        }
    }

    private func closeSwipe() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            offset = 0
        }
        anchor = 0
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let total = anchor + value.translation.width
                // Clamp: only left-swipe (negative), bottomed at revealWidth.
                offset = min(0, max(-revealWidth, total))
            }
            .onEnded { value in
                let total = anchor + value.translation.width
                let target: CGFloat = (total < -revealWidth / 2) ? -revealWidth : 0
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    offset = target
                }
                anchor = target
            }
    }
}
