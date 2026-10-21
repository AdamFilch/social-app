#if targetEnvironment(simulator)
import AVFoundation
import ButtercupKit

enum TestClipCapturer {
    static func start(_ capturer: BufferCapturer) {
        guard let url = Bundle.main.url(forResource: "test-clip", withExtension: "mp4") else { return }
        Task.detached { [weak capturer] in
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .video).first else { return }
            let fps = (try? await track.load(.nominalFrameRate)) ?? 15
            while true {
                guard let reader = try? AVAssetReader(asset: asset) else { return }
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                ])
                reader.add(output)
                reader.startReading()
                while let sample = output.copyNextSampleBuffer() {
                    guard let capturer else { return }
                    if let pixels = CMSampleBufferGetImageBuffer(sample) { capturer.capture(pixels) }
                    try? await Task.sleep(for: .seconds(1 / Double(fps)))
                }
            }
        }
    }
}
#endif
