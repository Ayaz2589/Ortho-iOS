import SwiftUI

/// One user row inside the inset card on the Settings screen.
struct UserRowView: View {
    let user: User
    var detail: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                avatar
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.text)
                        .tracking(-0.2)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.text.opacity(0.58))
                            .tracking(-0.1)
                    }
                }
                Spacer()
                ChevronView()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var avatar: some View {
        let palette = user.palette
        return Text(user.initial)
            .font(.system(size: user.initial.count > 1 ? 13 : 17, weight: .semibold))
            .foregroundStyle(palette.fg)
            .frame(width: 40, height: 40)
            .background(Circle().fill(palette.bg))
    }
}

/// Inline action row — lives inside the same card as users so the "add"
/// affordance reads as part of the list, not as floating chrome.
struct AddUserRowView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.text.opacity(0.05))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                Text("Add user")
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.accent)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChevronView: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.text.opacity(0.36))
    }
}
