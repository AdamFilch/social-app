import ButtercupKit
import SwiftUI

enum AppTab: CaseIterable {
    case calling, notes, hobbies

    var title: String {
        switch self {
        case .calling: "Calling"
        case .notes: "Notes"
        case .hobbies: "Hobbies"
        }
    }

    var systemImage: String {
        switch self {
        case .calling: "phone"
        case .notes: "note.text"
        case .hobbies: "star"
        }
    }
}

struct ContentView: View {
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls
    @State private var selection: AppTab = .calling

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(value: tab) {
                    Group {
                        if tab == .calling {
                            CallingView()
                        } else {
                            Text(tab.title)
                        }
                    }
                    .toolbar(.hidden, for: .tabBar)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(selection: $selection)
        }
        .accessibilityHidden(calls.showsCallScreen)
        .overlay {
            if calls.showsCallScreen {
                Group {
                    if calls.phase == .outgoing { OutgoingView() } else { InCallView() }
                }
                .accessibilityAddTraits(.isModal)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: calls.phase)
        .sheet(isPresented: .constant(calls.phase == .incoming)) { IncomingSheet() }
        .alert(failureMessage, isPresented: Binding(get: { calls.failure != nil }, set: { if !$0 { calls.failure = nil } })) {}
        .sensoryFeedback(.success, trigger: calls.connectedAt) { _, new in new != nil }
        .sensoryFeedback(.error, trigger: calls.failure) { _, new in new != nil }
        .task { await calls.listen() }
    }

    private var failureMessage: String {
        let name = session.partner?.displayName ?? ""
        return calls.failure == .busy ? "\(name) is on another call" : "Couldn't reach \(name). Try again"
    }
}

struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .background(.bar)
        .animation(.easeOut(duration: 0.15), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    ContentView()
        .environment(SessionStore())
        .environment(CallStore(session: SessionStore()))
}
