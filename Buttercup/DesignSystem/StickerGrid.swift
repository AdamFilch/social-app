import SwiftUI

enum Stickers {
    static let names = (Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "stickers") ?? [])
        .map { $0.deletingPathExtension().lastPathComponent }
        .sorted()

    static func image(_ name: String) -> Image {
        Image(uiImage: UIImage(named: "stickers/\(name).png") ?? UIImage())
    }

    static func label(_ name: String) -> String {
        name.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

struct StickerGrid: View {
    let names: [String]
    var rows = 3
    var cellFill = Color("Background")
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(84), spacing: 8), count: rows), spacing: 8) {
                ForEach(names, id: \.self) { name in
                    cell(name)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: CGFloat(rows) * 84 + CGFloat(rows - 1) * 8)
    }

    private func cell(_ name: String) -> some View {
        Button {
            onTap(name)
        } label: {
            Stickers.image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .frame(width: 84, height: 84)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(cellFill))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .draggable(name) {
            Stickers.image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
        }
        .accessibilityLabel(Stickers.label(name))
        .accessibilityHint("Double-tap to add to the note")
    }
}
