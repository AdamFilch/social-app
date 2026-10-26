import ButtercupKit
import SwiftUI

struct IncomingSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls

    var body: some View {
        VStack(spacing: 16) {
            Avatar(profile: session.partner, size: 88)
            Text("\(session.partner?.displayName ?? "") is calling")
                .font(.title2.weight(.heavy))
            Label(calls.call?.isVideo == true ? "Video" : "Audio", systemImage: calls.call?.isVideo == true ? "video.fill" : "phone.fill")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    Task { await calls.end() }
                } label: {
                    Label("Decline", systemImage: "phone.down.fill").frame(maxWidth: .infinity)
                }
                .tint(Color("Danger"))
                Button {
                    Task { await calls.answer() }
                } label: {
                    Label("Answer", systemImage: "phone.fill").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
