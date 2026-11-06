import SwiftUI

struct SkinTonePicker: View {
    let entry: EmojiEntry
    let selection: String
    let onPick: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach([entry] + (entry.tones ?? []), id: \.emoji) { option in
                Button {
                    onPick(option.emoji)
                } label: {
                    Text(option.emoji)
                        .font(.system(size: 34))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color("Divider")).opacity(option.emoji == selection ? 1 : 0))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(option.emoji == selection ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color("Surface")))
        .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2))
    }
}
