import SwiftUI

/// iOS-style swipe-action wrapper. Place around any row; horizontal drags
/// reveal one or two trailing actions. Stationary taps fall through to
/// any Button inside `content` (the `DragGesture` has a `minimumDistance`
/// threshold), so primary tap behavior is preserved.
///
/// When the row is open, an invisible tap-to-close overlay sits on top of
/// the slid content. Tapping anywhere on the content (other than the
/// revealed action buttons) snaps the swipe closed.
///
/// Layout when open (with both actions): `[ Copy ] [ Delete ]`
/// Delete is always the rightmost — matching iOS Mail's destructive-most
/// edge convention. Copy is opt-in via `onCopy`; when nil only the
/// Delete button shows.
struct SwipeActionRow<Content: View>: View {
    let onDelete: () -> Void
    var onCopy: (() -> Void)? = nil
    /// Fires on a tap that didn't turn into a swipe. Uses SwiftUI's
    /// `TapGesture` (via `.onTapGesture`) so the tap auto-cancels if the
    /// finger moves more than a few points — the trailing tap-up of a
    /// horizontal swipe won't trigger it.
    var onTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    private let buttonWidth: CGFloat = 84
    private var revealWidth: CGFloat {
        onCopy == nil ? buttonWidth : buttonWidth * 2
    }

    @State private var offset: CGFloat = 0
    /// Position the content has settled at between drags (0 = closed,
    /// -revealWidth = fully open). New drags start from here.
    @State private var anchor: CGFloat = 0

    private var isOpen: Bool { offset < -1 }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Underlying action tray — covered by `content` until the user
            // swipes left. Both actions stretch the row's full height so
            // tappable areas match the iOS swipe-action pattern.
            HStack(spacing: 0) {
                if let onCopy {
                    Button {
                        triggerCopy(onCopy)
                    } label: {
                        actionLabel(text: "Copy",
                                    icon: "doc.on.doc",
                                    background: AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    triggerDelete()
                } label: {
                    actionLabel(text: "Delete",
                                icon: "trash",
                                background: AppTheme.destructive)
                }
                .buttonStyle(.plain)
            }
            .frame(width: revealWidth)
            .frame(maxHeight: .infinity)

            // Foreground content slides over the buttons.
            content()
                .background(AppTheme.surface)
                .offset(x: offset)
                .contentShape(Rectangle())
                // `TapGesture` cancels itself when the finger moves more
                // than a few points, so a horizontal swipe won't end up
                // firing onTap as it lifts. Only attach when not open —
                // when the tray is showing we want taps to close it,
                // handled by the overlay below.
                .onTapGesture {
                    if !isOpen { onTap?() }
                }
                .overlay {
                    // Tap-to-close while open. The overlay sits above the
                    // content so its tap gesture wins, swallowing the tap
                    // before the row's onTap sees it.
                    if isOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { closeSwipe() }
                    }
                }
                // `simultaneousGesture` so the swipe doesn't block the
                // parent ScrollView's vertical scroll. Both gestures
                // receive the touch — the swipe only mutates `offset`
                // when the drag is horizontally dominant, so a vertical
                // drag is a no-op here and the ScrollView handles it.
                .simultaneousGesture(swipeGesture)
        }
    }

    // MARK: - Action labels

    private func actionLabel(text: String,
                             icon: String,
                             background: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(width: buttonWidth)
        .frame(maxHeight: .infinity)
        .background(background)
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

    /// Copy is non-destructive — snap closed first, then fire the callback
    /// so a sheet presented from the action doesn't compete with the swipe
    /// animation.
    private func triggerCopy(_ handler: @escaping () -> Void) {
        closeSwipe()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            handler()
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
                // Only react when the drag is predominantly horizontal —
                // a vertical-dominant drag belongs to the parent ScrollView,
                // and running through the swipe logic for it would jerk
                // the row sideways while the user is scrolling.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let total = anchor + value.translation.width
                // Clamp: only left-swipe (negative), bottomed at revealWidth.
                offset = min(0, max(-revealWidth, total))
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let total = anchor + value.translation.width
                let target: CGFloat = (total < -revealWidth / 2) ? -revealWidth : 0
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    offset = target
                }
                anchor = target
            }
    }
}
