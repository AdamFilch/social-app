import ButtercupKit
import SwiftUI

struct RecordFlow: View {
    @Binding var open: Bool
    @Environment(SoundsStore.self) private var store
    @Environment(SessionStore.self) private var session
    @Environment(CallStore.self) private var calls
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = SoundRecorder()
    @State private var player = SoundPlayer()
    @State private var phase: Phase?
    @State private var confirming = false
    @State private var title = ""
    @State private var saveFailed = false
    @State private var errors = 0
    @FocusState private var fieldFocused: Bool
    @AccessibilityFocusState private var stopFocused: Bool
    @AccessibilityFocusState private var confirmFocused: Bool

    private enum Phase { case preparing, recording, naming, denied }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ZStack {
            DialogCard(
                isPresented: .constant(phase != nil && phase != .preparing),
                scrimDismisses: false,
                onEscape: escape,
                alignment: phase == .naming ? .bottom : .center
            ) {
                card
            }
            .accessibilityHidden(confirming)
            if confirming { confirmCard }
        }
        .animation(.easeOut(duration: 0.15), value: phase)
        .animation(.easeOut(duration: 0.15), value: confirming)
        .sensoryFeedback(.error, trigger: errors)
        .onChange(of: open) { _, isOpen in
            if isOpen && phase == nil { Task { await begin() } }
        }
        .onChange(of: recorder.isRecording) { _, recording in
            guard !recording, phase == .recording, !confirming else { return }
            if recorder.autoStopped { AccessibilityNotification.Announcement("Stopped at 10 seconds").post() }
            toNaming()
        }
        .onChange(of: scenePhase) { _, new in
            if new == .background, phase == .recording || phase == .naming { close() }
        }
        .onChange(of: calls.phase) { _, new in
            if new != .idle, phase == .recording || phase == .naming { close() }
        }
    }

    @ViewBuilder private var card: some View {
        switch phase {
        case .recording: recordingContent.transition(.opacity)
        case .naming: namingContent.transition(.opacity)
        case .denied: deniedContent.transition(.opacity)
        default: EmptyView()
        }
    }

    private var recordingContent: some View {
        let seconds = Int(recorder.elapsed)
        return VStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle().fill(Color("Danger")).frame(width: 12, height: 12).accessibilityHidden(true)
                Text("Recording").font(.title3.weight(.heavy)).foregroundStyle(Color("TextPrimary"))
                Spacer()
                IconCircleButton(symbol: "xmark", label: "Discard recording") {
                    confirming = true
                    recorder.stop()
                }
            }
            .frame(minHeight: 44)
            VStack(spacing: 8) {
                WaveformTrack(levels: recorder.levels, mode: .recording(elapsed: recorder.elapsed, limit: SoundRecorder.limit), height: 72)
                HStack {
                    Text(String(format: "0:%02d", seconds))
                        .font(.title2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Color("TextPrimary"))
                    Spacer()
                    Text("\(Int(SoundRecorder.limit) - seconds) s left")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color("TextSecondary"))
                }
                .accessibilityHidden(true)
            }
            Button { recorder.stop() } label: {
                Circle()
                    .fill(Color("Accent"))
                    .frame(width: 88, height: 88)
                    .overlay(Circle().strokeBorder(Color("Outline"), lineWidth: 2.5))
                    .overlay(RoundedRectangle(cornerRadius: 6).fill(Color("OnAccent")).frame(width: 28, height: 28))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Stop recording")
            .accessibilityFocused($stopFocused)
            Text("Stops by itself at 10 seconds")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    private var namingContent: some View {
        let playing = player.playingID != nil
        return VStack(spacing: 14) {
            Text("Name this sound")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color("TextPrimary"))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                IconCircleButton(symbol: playing ? "stop.fill" : "play.fill", label: playing ? "Stop" : "Play sound", style: .accent) {
                    if playing { player.stop() } else { player.preview(recorder.fileURL, durationMs: recorder.durationMs) }
                }
                TimelineView(.animation(paused: !playing)) { context in
                    WaveformTrack(levels: recorder.levels, mode: .playback(progress: playing ? player.progress(at: context.date) : nil), height: 52)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color("TextSecondary"))
                    .accessibilityHidden(true)
                NameField(title: $title, focused: $fieldFocused) { if canSave { save() } }
                if saveFailed {
                    Text("Couldn't save. Try again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("Danger"))
                }
            }
            HStack {
                Button("Discard") {
                    fieldFocused = false
                    player.stop()
                    confirming = true
                }
                .font(.headline)
                .foregroundStyle(Color("TextPrimary"))
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(PillButtonStyle(sticker: true))
                    .disabled(!canSave)
                    .accessibilityHint(canSave ? "" : "Add a name first")
            }
        }
    }

    private var deniedContent: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Microphone is off").font(.title3.weight(.heavy)).foregroundStyle(Color("TextPrimary"))
                Spacer()
                IconCircleButton(symbol: "xmark", label: "Close", action: close)
            }
            .frame(minHeight: 44)
            Text("buttercup can't use the microphone. Turn it on in Settings")
                .font(.body)
                .foregroundStyle(Color("TextPrimary"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(PillButtonStyle(kind: .secondary))
        }
    }

    private var confirmCard: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: keep)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                Text("Discard this sound?")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color("TextPrimary"))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($confirmFocused)
                Text("You'll lose this recording. \(session.partner?.displayName ?? "Your partner") never hears it.")
                    .font(.body)
                    .foregroundStyle(Color("TextPrimary"))
                HStack(spacing: 12) {
                    Button(action: keep) { Text("Keep").frame(maxWidth: .infinity) }
                    Button(action: close) {
                        Label("Discard", systemImage: "trash")
                            .foregroundStyle(Color("Danger"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
            }
            .padding(16)
            .background(Color("Surface"), in: .rect(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Color("Outline"), lineWidth: 2.5))
            .padding(.horizontal, 20)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, keep)
        }
        .transition(.opacity)
        .task { confirmFocused = true }
    }

    private func begin() async {
        title = ""
        saveFailed = false
        phase = .preparing
        guard await recorder.permission() == .granted else {
            phase = .denied
            errors += 1
            return
        }
        recorder.start()
        if recorder.failed {
            errors += 1
            close()
            return
        }
        phase = .recording
        stopFocused = true
    }

    private func toNaming() {
        phase = .naming
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            fieldFocused = true
        }
    }

    private func keep() {
        confirming = false
        if phase == .recording { toNaming() } else { fieldFocused = true }
    }

    private func escape() {
        switch phase {
        case .recording:
            confirming = true
            recorder.stop()
        case .naming:
            fieldFocused = false
            player.stop()
            confirming = true
        default:
            close()
        }
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try store.save(fileURL: recorder.fileURL, title: name, durationMs: recorder.durationMs)
        } catch {
            saveFailed = true
            errors += 1
            return
        }
        AccessibilityNotification.Announcement("Saved \(name)").post()
        close()
    }

    private func close() {
        player.stop()
        recorder.discard()
        fieldFocused = false
        confirming = false
        phase = nil
        open = false
    }
}

struct NameField: View {
    @Binding var title: String
    var focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $title, prompt: Text("Like Miso's meow").foregroundStyle(Color("TextSecondary")))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color("TextPrimary"))
                .submitLabel(.done)
                .focused(focused)
                .onSubmit(onSubmit)
                .accessibilityLabel("Name")
                .accessibilityHint("Required")
            Text("\(title.count)/30")
                .font(.footnote.weight(.bold).monospacedDigit())
                .foregroundStyle(Color("TextSecondary"))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(Color("Background"), in: Capsule())
        .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2))
        .onChange(of: title) { _, new in
            if new.count > 30 { title = String(new.prefix(30)) }
        }
    }
}
