import ButtercupKit
import SwiftUI

struct CallingView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls

    var body: some View {
        let name = session.partner?.displayName ?? ""
        List {
            Section {
                VStack(spacing: 16) {
                    Avatar(profile: session.partner, size: 88)
                    Text(name)
                        .font(.title2.weight(.heavy))
                    HStack(spacing: 12) {
                        Button {
                            Task { await calls.startCall(video: false) }
                        } label: {
                            Label("Audio", systemImage: "phone.fill").frame(maxWidth: .infinity)
                        }
                        Button {
                            Task { await calls.startCall(video: true) }
                        } label: {
                            Label("Video", systemImage: "video.fill").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(calls.phase != .idle || session.partner == nil)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            if let history = calls.history {
                Section("Recent calls") {
                    if history.isEmpty {
                        Text("No calls yet. Give \(name) a ring?")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(history) { call in
                        CallRow(call: call, outgoing: call.callerId == session.me?.id)
                    }
                }
            }
            Section {
                Button("Sign out", role: .destructive) { Task { await session.signOut() } }
            }
        }
        .task { await calls.loadHistory() }
    }
}

struct CallRow: View {
    let call: Call
    let outgoing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: call.status == "missed" ? "phone.down.fill" : outgoing ? "phone.arrow.up.right" : "phone.arrow.down.left")
                .foregroundStyle(call.status == "missed" ? Color("Danger") : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(call.isVideo ? "Video" : "Audio")
                Text(call.createdAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            detail
        }
    }

    @ViewBuilder private var detail: some View {
        switch call.status {
        case "missed": Text("Missed").foregroundStyle(Color("Danger"))
        case "declined": Text("Declined").foregroundStyle(.secondary)
        case "cancelled": Text("Cancelled").foregroundStyle(.secondary)
        default:
            if let duration = call.duration {
                Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct Avatar: View {
    let profile: Profile?
    var size: CGFloat = 64

    var body: some View {
        Text(profile?.displayName.prefix(1).uppercased() ?? "")
            .font(.system(size: size * 0.42, weight: .heavy))
            .foregroundStyle(Color("OnAccent"))
            .frame(width: size, height: size)
            .background(Color(profile?.avatarTint ?? "NotePaperYellow"), in: .circle)
    }
}
