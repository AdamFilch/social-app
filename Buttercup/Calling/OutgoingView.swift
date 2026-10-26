import ButtercupKit
import SwiftUI

struct OutgoingView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Avatar(profile: session.partner, size: 120)
            Text("Calling \(session.partner?.displayName ?? "")…")
                .font(.title2.weight(.heavy))
            Spacer()
            Button(role: .destructive) {
                Task { await calls.end() }
            } label: {
                Label("Cancel", systemImage: "phone.down.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("Danger"))
            .controlSize(.large)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
    }
}
