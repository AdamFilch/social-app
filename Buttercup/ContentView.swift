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
    @State private var selection: AppTab = .calling

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(value: tab) {
                    Text(tab.title)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(selection: $selection)
        }
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
}
