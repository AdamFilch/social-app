import ButtercupKit
import SwiftUI

struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        Form {
            if codeSent {
                Section("Enter the code sent to \(email)") {
                    TextField("123456", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                    Button("Sign in") { run { try await session.verify(email: email, code: code) } catch: { "That code didn't work." } }
                        .disabled(code.count != 6 || busy)
                    Button("Use a different email") { codeSent = false; code = ""; error = nil }
                }
            } else {
                Section("Your email") {
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Send code") {
                        run { try await session.sendCode(to: email); codeSent = true } catch: { "Couldn't send the code. Try again." }
                    }
                    .disabled(!email.contains("@") || !email.contains(".") || busy)
                }
            }
            if let error {
                Text(error).foregroundStyle(Color("Danger"))
            }
        }
        .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
    }

    private func run(_ action: @escaping () async throws -> Void, catch message: @escaping () -> String) {
        busy = true
        error = nil
        Task {
            do { try await action() } catch { self.error = message() }
            busy = false
        }
    }
}

struct NameView: View {
    @Environment(SessionStore.self) private var session
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section("What's your name?") {
                TextField("Name", text: $name)
                    .textContentType(.givenName)
                Button("Continue") {
                    Task {
                        do { try await session.saveName(name.trimmingCharacters(in: .whitespacesAndNewlines)) } catch { self.error = "Couldn't save your name. Try again." }
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error {
                Text(error).foregroundStyle(Color("Danger"))
            }
        }
        .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
    }
}

struct PairView: View {
    @Environment(SessionStore.self) private var session
    @State private var inviteCode: String?
    @State private var pasted = ""

    var body: some View {
        Form {
            Section("Invite your partner") {
                if let inviteCode, let url = URL(string: "buttercup://invite/\(inviteCode)") {
                    ShareLink("Invite", item: url, message: Text("Pair with me on buttercup"))
                    Text(inviteCode)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                } else {
                    ProgressView()
                }
            }
            Section("Or paste their code") {
                TextField("Code", text: $pasted)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Pair") { Task { await session.acceptInvite(pasted.trimmingCharacters(in: .whitespacesAndNewlines)) } }
                    .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error = session.inviteError {
                Text(error).foregroundStyle(Color("Danger"))
            }
            Section {
                Button("Sign out", role: .destructive) { Task { await session.signOut() } }
            }
        }
        .sensoryFeedback(.error, trigger: session.inviteError) { _, new in new != nil }
        .task { inviteCode = try? await session.createInvite() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await session.refresh()
            }
        }
    }
}
