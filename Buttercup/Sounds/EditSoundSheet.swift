import ButtercupKit
import SwiftUI
import UIKit

struct EditSoundSheet: View {
    let sound: SoundRecord
    @Environment(SoundsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var emoji: String?
    @State private var start: Int
    @State private var end: Int
    @State private var levels: [Float] = []
    @State private var player = SoundPlayer()
    @State private var confirming = false
    @FocusState private var fieldFocused: Bool
    @AccessibilityFocusState private var confirmFocused: Bool

    init(sound: SoundRecord) {
        self.sound = sound
        _title = State(initialValue: sound.title)
        _emoji = State(initialValue: sound.emoji)
        _start = State(initialValue: sound.trimStartMs)
        _end = State(initialValue: sound.trimEndMs)
    }

    private var name: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var changed: Bool { name != sound.title || emoji != sound.emoji || start != sound.trimStartMs || end != sound.trimEndMs }
    private var canSave: Bool { changed && !name.isEmpty }
    private var trimmed: SoundRecord { sound.edited(title: name, emoji: emoji, trimStartMs: start, trimEndMs: end) }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        group("Name") {
                            NameField(title: $title, focused: $fieldFocused) { if canSave { save() } }
                        }
                        group("Emoji") {
                            HStack(spacing: 12) {
                                EmojiWell(emoji: $emoji)
                                if emoji != nil {
                                    Button("Remove") { emoji = nil }
                                        .buttonStyle(PillButtonStyle(kind: .secondary, size: .small))
                                        .accessibilityLabel("Remove emoji")
                                }
                                Text("Shows 🔊 when there's none")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color("TextSecondary"))
                            }
                        }
                        trim
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .accessibilityHidden(confirming)
            DialogCard(isPresented: $confirming) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Discard changes?")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($confirmFocused)
                    HStack(spacing: 12) {
                        Button { confirming = false } label: { Text("Keep editing").frame(maxWidth: .infinity) }
                        Button { dismiss() } label: {
                            Text("Discard").foregroundStyle(Color("Danger")).frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                }
                .task { confirmFocused = true }
            }
        }
        .background(Color("Surface"))
        .presentationDetents([.large])
        .presentationBackground(Color("Surface"))
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(changed)
        .accessibilityAction(.escape, cancel)
        .task {
            guard let url = try? await store.file(for: sound) else { return }
            levels = await Task.detached { waveformLevels(of: url) }.value
        }
        .onDisappear { player.stop() }
    }

    private var header: some View {
        ZStack {
            Text("Edit sound")
                .font(.headline)
                .foregroundStyle(Color("TextPrimary"))
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Cancel", action: cancel)
                    .font(.headline)
                    .foregroundStyle(Color("TextPrimary"))
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(PillButtonStyle(size: .small, sticker: true))
                    .disabled(!canSave)
                    .accessibilityHint(name.isEmpty ? "Add a name first" : "")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var trim: some View {
        let playing = player.playingID != nil
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                label("Trim")
                Spacer()
                Text(String(format: "%.1f s of %.1f s", Double(end - start) / 1000, Double(sound.durationMs) / 1000))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color("TextSecondary"))
            }
            TimelineView(.animation(paused: !playing)) { context in
                SoundTrimmer(
                    levels: levels,
                    durationMs: sound.durationMs,
                    start: $start,
                    end: $end,
                    playhead: playing ? (Double(start) + player.progress(at: context.date) * Double(end - start)) / Double(max(sound.durationMs, 1)) : nil
                )
            }
            .onChange(of: start) { player.stop() }
            .onChange(of: end) { player.stop() }
            HStack(spacing: 10) {
                Button {
                    if playing { player.stop() } else { player.tap(trimmed, store: store) }
                } label: {
                    Label(playing ? "Stop" : "Play trimmed", systemImage: playing ? "stop.fill" : "play.fill")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary, size: .small))
                if playing {
                    Text("Playing the trimmed part")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            .padding(.top, 4)
        }
    }

    private func group(_ text: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(text)
            content()
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color("TextSecondary"))
            .accessibilityHidden(true)
    }

    private func cancel() {
        fieldFocused = false
        player.stop()
        if changed { confirming = true } else { dismiss() }
    }

    private func save() {
        guard canSave else { return }
        player.stop()
        store.update(sound, title: name, emoji: emoji, trimStartMs: start, trimEndMs: end)
        dismiss()
    }
}

struct EmojiWell: View {
    @Binding var emoji: String?
    @State private var picking = false

    var body: some View {
        Button { picking = true } label: {
            Text(emoji ?? "🔊")
                .font(.system(size: 36))
                .frame(width: 64, height: 64)
                .background(Color("Background"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color("Outline"), lineWidth: picking ? 3 : 2))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(EmojiField(picking: $picking) { emoji = $0 }.frame(width: 1, height: 1).opacity(0).accessibilityHidden(true))
        .accessibilityLabel("Emoji, \(emoji.flatMap { $0.unicodeScalars.first?.properties.name?.lowercased() } ?? "none")")
        .accessibilityHint("Double-tap to choose")
    }
}

private struct EmojiField: UIViewRepresentable {
    @Binding var picking: Bool
    let onPick: (String) -> Void

    final class Field: UITextField {
        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiField
        init(_ parent: EmojiField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let pick = string.last(where: \.isEmoji) {
                parent.onPick(String(pick))
                textField.resignFirstResponder()
            }
            return false
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.picking = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> Field {
        let field = Field()
        field.delegate = context.coordinator
        field.tintColor = .clear
        return field
    }

    func updateUIView(_ field: Field, context: Context) {
        context.coordinator.parent = self
        if picking, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !picking, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation } || (unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji == true)
    }
}
