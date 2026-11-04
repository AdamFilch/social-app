import SwiftUI

struct StickerTray: View {
    static let small = PresentationDetent.height(110)

    @Environment(StickerLayer.self) private var stickers
    @Binding var detent: PresentationDetent
    @State private var tab = Tab.emoji
    @State private var typed = ""
    @State private var text = ""
    @State private var color = StickerColor.ink

    enum Tab {
        case emoji, text, images
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Sticker kind", selection: $tab) {
                Text("Emoji").tag(Tab.emoji)
                Text("Text").tag(Tab.text)
                Text("Images").tag(Tab.images)
            }
            .pickerStyle(.segmented)

            if stickers.blocked {
                Text(stickers.faceTracked ? "That's 10. Remove one to add more." : "Show your face to add stickers")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextSecondary"))
            }

            ScrollView {
                switch tab {
                case .emoji: emoji
                case .text: textTab
                case .images: images
                }
            }
        }
        .padding(24)
        .animation(.easeOut(duration: 0.15), value: tab)
    }

    private var emoji: some View {
        VStack(spacing: 16) {
            grid(Sticker.emoji) { emoji in
                item(.emoji(emoji)) { Text(emoji).font(.system(size: 40)) }
            }
            TextField("Or type any emoji", text: $typed)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    guard let first = typed.first else { return }
                    place(.emoji(String(first)))
                    typed = ""
                }
                .dimmed(stickers.blocked)
        }
    }

    private var textTab: some View {
        VStack(spacing: 16) {
            TextField("Your text", text: $text)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                ForEach(StickerColor.allCases) { swatch in
                    Button { color = swatch } label: {
                        Circle()
                            .fill(Color(swatch.uiColor))
                            .strokeBorder(Color("Outline"), lineWidth: color == swatch ? 3 : 1.5)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(color == swatch ? .isSelected : [])
                }
            }
            item(.text(text, color)) {
                Text("Add")
                    .font(.headline)
                    .foregroundStyle(Color("OnAccent"))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color("Accent"), in: .capsule)
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder private var images: some View {
        if Sticker.images.isEmpty {
            Text("No image stickers yet.")
                .foregroundStyle(Color("TextSecondary"))
                .padding(.top, 32)
        } else {
            grid(Sticker.images) { name in
                item(.image(name)) {
                    Image(uiImage: Sticker.imageURL(name).flatMap { UIImage(contentsOfFile: $0.path) } ?? UIImage())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .accessibilityLabel(name)
                }
            }
        }
    }

    private func grid<Content: View>(_ values: [String], @ViewBuilder content: @escaping (String) -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 12) {
            ForEach(values, id: \.self, content: content)
        }
    }

    private func item<Label: View>(_ kind: Sticker.Kind, @ViewBuilder label: () -> Label) -> some View {
        Button { place(kind) } label: { label() }
            .buttonStyle(.plain)
            .dimmed(stickers.blocked)
            .onDrag {
                guard !stickers.blocked else { return NSItemProvider() }
                stickers.dragging = Sticker(kind: kind)
                detent = Self.small
                return NSItemProvider(object: "sticker" as NSString)
            }
    }

    private func place(_ kind: Sticker.Kind) {
        stickers.add(Sticker(kind: kind), at: nil)
        detent = Self.small
    }
}

private extension View {
    func dimmed(_ off: Bool) -> some View {
        disabled(off).opacity(off ? 0.4 : 1)
    }
}
