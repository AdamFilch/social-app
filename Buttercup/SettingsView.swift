import ButtercupKit
import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Account") {
                    Button("Sign out", role: .destructive) { Task { await session.signOut() } }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
