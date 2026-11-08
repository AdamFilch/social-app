import AVFoundation
import ButtercupKit
import Observation

@Observable @MainActor
final class SoundRecorder {
    static let limit: TimeInterval = 10
    static let barInterval: Duration = .milliseconds(190)

    enum Permission { case granted, denied }

    private(set) var levels: [Float] = []
    private(set) var elapsed: TimeInterval = 0
    private(set) var isRecording = false
    private(set) var failed = false
    private(set) var autoStopped = false
    private var recorder: AVAudioRecorder?
    private var task: Task<Void, Never>?

    let fileURL = Outbox.directory.appending(path: "Recordings/draft.m4a")

    var durationMs: Int { Int(elapsed * 1000) }

    func permission() async -> Permission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        default: return await AVAudioApplication.requestRecordPermission() ? .granted : .denied
        }
    }

    func start() {
        failed = false
        autoStopped = false
        levels = []
        elapsed = 0
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: fileURL)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let recorder = try AVAudioRecorder(url: fileURL, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64000,
            ])
            recorder.isMeteringEnabled = true
            guard recorder.record(forDuration: Self.limit) else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder
        } catch {
            failed = true
            return
        }
        isRecording = true
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.barInterval)
                guard !Task.isCancelled, let recorder else { return }
                recorder.updateMeters()
                let power = max(recorder.averagePower(forChannel: 0), -50)
                levels.append((power + 50) / 50)
                elapsed = recorder.isRecording ? min(recorder.currentTime, Self.limit) : Self.limit
                if !recorder.isRecording || recorder.currentTime >= Self.limit - 0.05 {
                    elapsed = Self.limit
                    autoStopped = true
                    stop()
                    return
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        guard let recorder else { return }
        elapsed = min(max(elapsed, recorder.currentTime), Self.limit)
        recorder.stop()
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func discard() {
        stop()
        try? FileManager.default.removeItem(at: fileURL)
        levels = []
        elapsed = 0
    }
}
