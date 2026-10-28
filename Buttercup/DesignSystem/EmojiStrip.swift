import CoreText
import SwiftUI

struct EmojiEntry: Decodable {
    let emoji: String
    let name: String
    let tones: [EmojiEntry]?

    enum CodingKeys: String, CodingKey {
        case emoji = "e", name = "n", tones = "t"
    }
}

struct EmojiCategory: Decodable, Identifiable {
    let name: String
    let symbol: String
    let emoji: [EmojiEntry]

    var id: String { name }
}

enum Emoji {
    static let categories: [EmojiCategory] = {
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let all = try? JSONDecoder().decode([EmojiCategory].self, from: data) else { return [] }
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 40, nil)
        return all.map { category in
            EmojiCategory(name: category.name, symbol: category.symbol, emoji: category.emoji.compactMap { entry in
                guard renders(entry.emoji, font) else { return nil }
                let tones = entry.tones.flatMap { tones in tones.allSatisfy { renders($0.emoji, font) } ? tones : nil }
                return EmojiEntry(emoji: entry.emoji, name: entry.name, tones: tones)
            })
        }
    }()

    static let names: [String: String] = Dictionary(
        categories.flatMap(\.emoji).flatMap { [$0] + ($0.tones ?? []) }.map { ($0.emoji, $0.name) },
        uniquingKeysWith: { first, _ in first }
    )

    private static func renders(_ emoji: String, _ font: CTFont) -> Bool {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: emoji, attributes: [.font: font]))
        guard CTLineGetGlyphCount(line) == 1,
              let run = (CTLineGetGlyphRuns(line) as? [CTRun])?.first,
              let runFont = (CTRunGetAttributes(run) as NSDictionary)[NSAttributedString.Key.font] else { return false }
        return CTFontCopyPostScriptName(runFont as! CTFont) as String == "AppleColorEmoji"
    }
}

struct EmojiStrip: View {
    let categories: [EmojiCategory]
    var rows = 3
    let onTap: (String) -> Void
    @State private var current: String?
    @State private var toning: Toning?
    @State private var isJumping = false

    private struct Toning {
        let entry: EmojiEntry
        let selection: String
        let frame: CGRect
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 6) {
                strip
                chips(proxy)
            }
        }
        .coordinateSpace(.named("EmojiStrip"))
        .overlay { picker }
        .onAppear { if current == nil { current = categories.first?.id } }
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 20) {
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(category.name)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color("TextSecondary"))
                            .frame(height: 18)
                            .accessibilityAddTraits(.isHeader)
                        LazyHGrid(rows: Array(repeating: GridItem(.fixed(72), spacing: 4), count: rows), spacing: 4) {
                            ForEach(category.emoji, id: \.emoji) { entry in
                                EmojiCell(entry: entry, onTap: { if toning == nil { onTap($0) } }) { shown, frame in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        toning = Toning(entry: entry, selection: shown, frame: frame)
                                    }
                                }
                            }
                        }
                        .frame(width: width(of: category))
                    }
                    .id(category.id)
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x + $0.contentInsets.leading } action: { _, offset in
            guard !isJumping else { return }
            if let index = sectionStarts.lastIndex(where: { $0 <= offset + 1 }) { current = categories[index].id }
        }
        .onScrollPhaseChange { _, phase in
            if phase != .idle { closePicker() }
            if phase == .idle || phase == .interacting { isJumping = false }
        }
        .frame(height: 18 + CGFloat(rows) * 72 + CGFloat(rows - 1) * 4)
    }

    private var sectionStarts: [CGFloat] {
        var start: CGFloat = 0
        return categories.map { category in
            defer { start += width(of: category) + 20 }
            return start
        }
    }

    private func width(of category: EmojiCategory) -> CGFloat {
        CGFloat((category.emoji.count + rows - 1) / rows) * 76 - 4
    }

    private func chips(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(categories) { category in
                let isCurrent = category.id == current
                Button {
                    closePicker()
                    current = category.id
                    isJumping = true
                    withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo(category.id, anchor: .leading) }
                } label: {
                    Image(systemName: category.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(isCurrent ? "TextPrimary" : "TextSecondary"))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color("Divider")).opacity(isCurrent ? 1 : 0))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.15), value: isCurrent)
                .accessibilityLabel(category.name)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var picker: some View {
        if let toning {
            GeometryReader { geo in
                let half: CGFloat = 136
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closePicker)
                    .accessibilityHidden(true)
                SkinTonePicker(entry: toning.entry, selection: toning.selection) { emoji in
                    UserDefaults.standard.set(emoji, forKey: EmojiCell.toneKey(toning.entry.emoji))
                    closePicker()
                    onTap(emoji)
                }
                .position(
                    x: min(max(toning.frame.midX, half + 8), geo.size.width - half - 8),
                    y: toning.frame.minY - 30
                )
            }
            .transition(.asymmetric(insertion: .opacity, removal: .opacity.animation(.easeOut(duration: 0.1))))
        }
    }

    private func closePicker() {
        guard toning != nil else { return }
        withAnimation(.easeOut(duration: 0.1)) { toning = nil }
    }
}

private struct EmojiCell: View {
    let entry: EmojiEntry
    let onTap: (String) -> Void
    let onLongPress: (String, CGRect) -> Void
    @AppStorage private var tone: String
    @State private var frame = CGRect.zero

    static func toneKey(_ emoji: String) -> String { "emojiTone.\(emoji)" }

    init(entry: EmojiEntry, onTap: @escaping (String) -> Void, onLongPress: @escaping (String, CGRect) -> Void) {
        self.entry = entry
        self.onTap = onTap
        self.onLongPress = onLongPress
        _tone = AppStorage(wrappedValue: "", Self.toneKey(entry.emoji))
    }

    private var shown: String { tone.isEmpty ? entry.emoji : tone }

    var body: some View {
        Text(shown)
            .font(.system(size: 40))
            .frame(width: 72, height: 72)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("EmojiStrip")) } action: { frame = $0 }
            .onTapGesture { onTap(shown) }
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.3).onEnded { _ in
                if entry.tones != nil { onLongPress(shown, frame) }
            })
            .draggable(shown) {
                Text(shown).font(.system(size: 64))
            }
            .accessibilityElement()
            .accessibilityLabel(Emoji.names[shown] ?? entry.name)
            .accessibilityHint("Double-tap to add to the note")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onTap(shown) }
            .accessibilityActions {
                ForEach(entry.tones.map { [entry] + $0 } ?? [], id: \.emoji) { option in
                    Button(option.name) {
                        tone = option.emoji
                        onTap(option.emoji)
                    }
                }
            }
    }
}
