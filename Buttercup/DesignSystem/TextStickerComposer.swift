import SwiftUI

struct TextSticker: View {
    let text: String
    let font: NoteFont
    let colour: Color
    let size: CGFloat

    var body: some View {
        let label = Text(text).font(font.font(size: size)).fontDesign(nil).lineLimit(1).minimumScaleFactor(0.2)
        let outline = size * 3.5 / 52
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                let angle = Double(index % 16) * .pi / 8
                let radius = index < 16 ? outline : outline / 2
                label
                    .foregroundStyle(InkColour.ink.color)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
            label.foregroundStyle(colour)
        }
        .padding(outline)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }
}

struct TextStickerComposer: View {
    enum Preview { case inline, external }

    @Binding var text: String
    @Binding var colour: InkColour
    @Binding var font: NoteFont
    var focus: FocusState<Bool>.Binding
    let colours: [InkColour]
    var fonts: [NoteFont]?
    var addHasShadow = true
    var preview: Preview = .inline
    let onAdd: () -> Void

    static let maxLength = 30

    private var canAdd: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                TextField("", text: $text, prompt: Text("Type something").foregroundStyle(Color("TextSecondary")))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color("TextPrimary"))
                    .submitLabel(.done)
                    .focused(focus)
                    .onSubmit { if canAdd { onAdd() } }
                    .onChange(of: text) { _, new in
                        if new.count > Self.maxLength { text = String(new.prefix(Self.maxLength)) }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Capsule().fill(Color("Background")))
                    .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2))
                    .accessibilityLabel("Sticker text")
                Button("Add", action: onAdd)
                    .buttonStyle(PillButtonStyle(height: 48, sticker: addHasShadow))
                    .disabled(!canAdd)
            }
            .padding(.horizontal, 16)
            ColourDots(colours: colours, selection: $colour, layout: .row, colour: \.color, name: \.name)
            if let fonts {
                HStack(spacing: 8) {
                    ForEach(fonts, id: \.self) { chip($0) }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            if preview == .inline {
                TextSticker(text: text.isEmpty ? "Type something" : text, font: font, colour: colour.color, size: 40)
                    .opacity(text.isEmpty ? 0.4 : 1)
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color("Background")))
                    .padding(.horizontal, 16)
                    .accessibilityHidden(true)
            }
        }
    }

    private func chip(_ value: NoteFont) -> some View {
        let selected = value == font
        return Button {
            font = value
        } label: {
            HStack(spacing: 4) {
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                }
                Text(value.title).font(value.font(size: value.labelSize)).fontDesign(nil)
            }
            .foregroundStyle(Color(selected ? "OnAccent" : "TextPrimary"))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(Color(selected ? "Accent" : "Surface")))
            .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2))
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
        .accessibilityLabel("\(value.title) font")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
