import SwiftUI

/// Two-step magic-link sign-in: email entry → 6-digit code from the email.
/// Success drives `AppState.session` non-nil; the auth gate in
/// `Ortho_iOSApp` then swaps in `RootTabView`.
struct SignInView: View {
    @Environment(AppState.self) private var appState

    @State private var email: String = ""
    @State private var code: String = ""
    @FocusState private var focused: Field?

    private enum Field { case email, code }

    private var step: Step {
        appState.pendingSignInEmail == nil ? .email : .code
    }
    private enum Step { case email, code }

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("ORTHO")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.text3)

                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case .email: emailStep
                    case .code:  codeStep
                    }
                }
                .padding(28)
                .frame(maxWidth: 400)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let error = appState.authError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.destructive)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                        .padding(.horizontal, 16)
                }

                Spacer()
            }
            .padding(.top, 80)
            .padding(.horizontal, 24)
        }
        .onAppear { focused = step == .email ? .email : .code }
        .onChange(of: step) { _, newValue in
            focused = newValue == .email ? .email : .code
        }
    }

    @ViewBuilder
    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sign in to Ortho")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.text)
            Text("We'll email you a 6-digit code.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.text2)
        }

        TextField("you@example.com", text: $email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 16))
            .foregroundStyle(AppTheme.text)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(AppTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .focused($focused, equals: .email)
            .submitLabel(.send)
            .onSubmit(sendCode)

        primaryButton(
            title: "Send code",
            disabled: !isValidEmail(email) || appState.isAuthLoading,
            action: sendCode
        )
    }

    @ViewBuilder
    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Enter your code")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.text)
            Text("Sent to **\(appState.pendingSignInEmail ?? "")**.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.text2)
        }

        TextField("12345678", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .tracking(4)
            .foregroundStyle(AppTheme.text)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(AppTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .focused($focused, equals: .code)
            .onChange(of: code) { _, newValue in
                code = String(newValue.filter(\.isNumber).prefix(8))
            }

        primaryButton(
            title: "Verify",
            disabled: code.count < 6 || appState.isAuthLoading,
            action: verifyCode
        )

        Button("Use a different email") {
            appState.resetSignInFlow()
            code = ""
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(AppTheme.text2)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func primaryButton(title: String,
                               disabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if appState.isAuthLoading {
                    ProgressView()
                        .tint(AppTheme.bg)
                } else {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled ? AppTheme.text.opacity(0.3) : AppTheme.text)
            .foregroundStyle(AppTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func sendCode() {
        Task { await appState.requestSignInCode(email: email) }
    }

    private func verifyCode() {
        Task {
            await appState.verifyCode(
                email: appState.pendingSignInEmail ?? "",
                code: code
            )
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }
}

#Preview("Sign in · Light") {
    SignInView()
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Sign in · Dark") {
    SignInView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
