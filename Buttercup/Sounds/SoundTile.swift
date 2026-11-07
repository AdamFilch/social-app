import ButtercupKit
import SwiftUI

struct SoundTile: View {
    let sound: SoundRecord
    let progress: Double?
    var loading = false
    var failed = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(sound.emoji ?? "🔊")
                    .font(.system(size: 30))
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Text(failed ? "Couldn't load. Try again" : sound.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(failed ? "Danger" : "TextPrimary"))
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                    .multilineTextAlignment(.leading)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 11, trailing: 12))
            .frame(maxWidth: .infinity, minHeight: 108, maxHeight: .infinity, alignment: .leading)
            .background(alignment: .leading) {
                GeometryReader { proxy in
                    if let progress {
                        Rectangle()
                            .fill(Color("PlayTint"))
                            .frame(width: proxy.size.width * (reduceMotion ? 0.5 : progress))
                            .transition(.opacity)
                    }
                }
            }
            .background(Color("Surface"))
            .overlay(alignment: .topTrailing) {
                if progress != nil {
                    Circle()
                        .fill(Color("TextPrimary"))
                        .frame(width: 26, height: 26)
                        .overlay(RoundedRectangle(cornerRadius: 2).fill(Color("Surface")).frame(width: 9, height: 9))
                        .padding(9)
                        .transition(.opacity)
                } else if loading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 26, height: 26)
                        .padding(9)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color("Outline"), lineWidth: 2.5))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: progress == nil)
        }
        .buttonStyle(TileButtonStyle(tint: "TextPrimary", amount: 0.06))
        .accessibilityLabel(sound.title)
        .accessibilityValue(progress != nil ? "Playing" : "")
        .accessibilityHint(progress != nil ? "Double-tap to stop" : "Double-tap to play")
    }
}

struct RecordTile: View {
    var sticker = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Circle()
                    .strokeBorder(Color("OnAccent"), lineWidth: 2)
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "plus").font(.system(size: 18, weight: .bold)))
                Spacer(minLength: 8)
                Text("Record")
                    .font(.subheadline.weight(.bold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
            .foregroundStyle(Color("OnAccent"))
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 11, trailing: 12))
            .frame(maxWidth: .infinity, minHeight: 108, maxHeight: .infinity, alignment: .leading)
            .background(Color("Accent"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color("Outline"), lineWidth: 2.5))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(TileButtonStyle(tint: "OnAccent", amount: 0.12, sticker: sticker))
        .accessibilityLabel("Record a sound")
        .accessibilityHint("Up to 10 seconds")
    }
}

private struct TileButtonStyle: ButtonStyle {
    let tint: String
    let amount: Double
    var sticker = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(tint).opacity(pressed ? amount : 0))
                    .allowsHitTesting(false)
            }
            .background {
                if sticker {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("Outline"))
                        .offset(x: pressed ? 0 : 3, y: pressed ? 0 : 3)
                }
            }
            .animation(.easeOut(duration: 0.1), value: pressed)
    }
}
