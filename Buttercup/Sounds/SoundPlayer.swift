import AVFoundation
import ButtercupKit
import Observation

@Observable @MainActor
final class SoundPlayer {
    private(set) var playingID: UUID?
    private(set) var loadingID: UUID?
    private(set) var failedID: UUID?
    private(set) var failures = 0
    private(set) var startedAt = Date.now
    private(set) var duration: TimeInterval = 1
    private var player: AVAudioPlayer?
    private var task: Task<Void, Never>?
    private var failTask: Task<Void, Never>?

    func progress(at date: Date) -> Double {
        min(max(date.timeIntervalSince(startedAt) / duration, 0), 1)
    }

    func tap(_ sound: SoundRecord, store: SoundsStore) {
        if playingID == sound.id || loadingID == sound.id {
            stop()
            return
        }
        stop()
        let local = store.localURL(for: sound)
        if FileManager.default.fileExists(atPath: local.path()) {
            start(sound, url: local)
            return
        }
        loadingID = sound.id
        task = Task {
            do {
                let url = try await store.file(for: sound)
                guard !Task.isCancelled else { return }
                loadingID = nil
                start(sound, url: url)
            } catch {
                guard !Task.isCancelled else { return }
                loadingID = nil
                fail(sound.id)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        loadingID = nil
        guard player != nil else { return }
        player?.stop()
        player = nil
        playingID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func start(_ sound: SoundRecord, url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = Double(sound.trimStartMs) / 1000
            guard player.play() else { throw CocoaError(.fileReadCorruptFile) }
            self.player = player
        } catch {
            fail(sound.id)
            return
        }
        playingID = sound.id
        startedAt = .now
        duration = max(Double(sound.trimEndMs - sound.trimStartMs) / 1000, 0.05)
        task = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            stop()
        }
    }

    private func fail(_ id: UUID) {
        failures += 1
        failedID = id
        failTask?.cancel()
        failTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if failedID == id { failedID = nil }
        }
    }
}
