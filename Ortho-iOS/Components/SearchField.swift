import SwiftUI

/// Search field with focus-driven affordances: tinted ring, clear button,
/// inline Cancel that resigns focus. Used in the activity list header.
struct SearchField: View {
    @Binding var text: String
    var placeholder: LocalizedStringKey = "Search"
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.lato(size: 14, weight: .medium))
                .foregroundStyle(focused ? AppTheme.accent : AppTheme.text2)

            TextField(placeholder, text: $text)
                .font(.lato(size: 15))
                .focused($focused)
                .submitLabel(.search)
                .tint(AppTheme.accent)

            if focused && !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.text2)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            if focused {
                Button("Cancel") {
                    text = ""
                    focused = false
                }
                .font(.lato(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.text.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(focused ? AppTheme.accent : .clear, lineWidth: 1.5)
                )
        )
        .padding(.horizontal, 16)
        .animation(.easeOut(duration: 0.15), value: focused)
        .animation(.easeOut(duration: 0.12), value: text.isEmpty)
    }
}
