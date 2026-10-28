import SwiftUI

struct PillTabRow<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    var disabled: Set<Tab> = []
    let title: (Tab) -> String
    var accessibilityLabel: ((Tab) -> String)? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs, id: \.self) { tab in
                        pill(tab)
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: selection) { _, new in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(new) }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func pill(_ tab: Tab) -> some View {
        let selected = tab == selection
        let isDisabled = disabled.contains(tab)
        return Button {
            selection = tab
        } label: {
            Text(title(tab))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(selected ? "OnAccent" : "TextPrimary"))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(selected ? Color("Accent") : .clear))
                .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2).opacity(selected ? 1 : 0))
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .id(tab)
        .accessibilityLabel(accessibilityLabel?(tab) ?? title(tab))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
