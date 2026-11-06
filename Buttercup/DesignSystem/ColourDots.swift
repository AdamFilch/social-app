import SwiftUI

struct ColourDots<Item: Hashable>: View {
    enum Layout {
        case row
        case grid(rows: Int)
    }

    let colours: [Item]
    @Binding var selection: Item
    var layout: Layout = .row
    let colour: (Item) -> Color
    let name: (Item) -> String

    private var rows: Int {
        switch layout {
        case .row: 1
        case .grid(let rows): rows
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(44), spacing: 4), count: rows), spacing: 4) {
                ForEach(colours, id: \.self) { item in
                    dot(item)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: CGFloat(rows) * 44 + CGFloat(rows - 1) * 4)
    }

    private func dot(_ item: Item) -> some View {
        let selected = item == selection
        return Button {
            selection = item
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color("Outline"), lineWidth: 2.5)
                    .frame(width: 41, height: 41)
                    .opacity(selected ? 1 : 0)
                Circle()
                    .fill(colour(item))
                    .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 2))
                    .frame(width: 30, height: 30)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
        .accessibilityLabel(name(item))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
