import AVFoundation
import SwiftUI

struct SoundTrimmer: View {
    let levels: [Float]
    let durationMs: Int
    @Binding var start: Int
    @Binding var end: Int
    let playhead: Double?

    private var trimmable: Bool { durationMs >= 500 }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let inner = width - 20
                let sx = 10 + inner * fraction(start)
                let ex = 10 + inner * fraction(end)
                ZStack(alignment: .topLeading) {
                    WaveformTrack(levels: levels, mode: .playback(progress: playhead), height: 76)
                        .overlay {
                            ZStack(alignment: .topLeading) {
                                Color("Background").opacity(0.78).frame(width: sx)
                                Color("Background").opacity(0.78).frame(width: max(width - ex, 0)).offset(x: ex)
                                Rectangle().fill(Color("Outline")).frame(width: max(ex - sx, 0), height: 3).offset(x: sx)
                                Rectangle().fill(Color("Outline")).frame(width: max(ex - sx, 0), height: 3).offset(x: sx, y: 73)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .allowsHitTesting(false)
                        }
                        .offset(y: 2)
                        .accessibilityHidden(true)
                    handle(label: "Start", ms: start, x: sx) { x in
                        start = min(snap(ms(at: x, inner: inner)), (end - 500) / 100 * 100)
                    } adjust: { step in
                        start = min(snap(Double(start + step)), (end - 500) / 100 * 100)
                    }
                    handle(label: "End", ms: end, x: ex) { x in
                        end = max(snap(ms(at: x, inner: inner)), start + 500)
                    } adjust: { step in
                        end = max(snap(Double(end + step)), start + 500)
                    }
                }
            }
            .frame(height: 80)
            .coordinateSpace(.named("trimmer"))
            .disabled(!trimmable)
            HStack {
                Text("start \(Text(seconds(start)).bold().foregroundStyle(Color("TextPrimary")))")
                Spacer()
                Text("end \(Text(seconds(end)).bold().foregroundStyle(Color("TextPrimary")))")
            }
            .font(.footnote.monospaced())
            .foregroundStyle(Color("TextSecondary"))
            .accessibilityHidden(true)
        }
    }

    private func handle(label: String, ms: Int, x: CGFloat, drag: @escaping (CGFloat) -> Void, adjust: @escaping (Int) -> Void) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color("Accent"))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color("Outline"), lineWidth: 2.5))
            .overlay(Capsule().fill(Color("OnAccent")).frame(width: 3, height: 22))
            .frame(width: 20, height: 80)
            .frame(width: 44, height: 80)
            .contentShape(.rect)
            .offset(x: x - 22)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("trimmer"))
                    .onChanged { drag($0.location.x) }
            )
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(String(format: "%.1f seconds", Double(ms) / 1000))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjust(100)
                case .decrement: adjust(-100)
                @unknown default: break
                }
            }
    }

    private func fraction(_ ms: Int) -> CGFloat {
        CGFloat(ms) / CGFloat(max(durationMs, 1))
    }

    private func ms(at x: CGFloat, inner: CGFloat) -> Double {
        Double((x - 10) / max(inner, 1)) * Double(durationMs)
    }

    private func snap(_ raw: Double) -> Int {
        if raw >= Double(durationMs - 50) { return durationMs }
        return min(max(Int((raw / 100).rounded()) * 100, 0), durationMs)
    }

    private func seconds(_ ms: Int) -> String {
        String(format: "%.1f s", Double(ms) / 1000)
    }
}

func waveformLevels(of url: URL) -> [Float] {
    guard let file = try? AVAudioFile(forReading: url),
          let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
          (try? file.read(into: buffer)) != nil,
          let samples = buffer.floatChannelData?[0] else { return [] }
    let frames = Int(buffer.frameLength)
    let bucket = max(Int(file.processingFormat.sampleRate * 0.05), 1)
    return stride(from: 0, to: frames, by: bucket).map { i in
        let n = min(bucket, frames - i)
        var sum: Float = 0
        for j in i..<(i + n) { sum += samples[j] * samples[j] }
        let db = 20 * log10(max((sum / Float(n)).squareRoot(), 1e-6))
        return (max(db, -50) + 50) / 50
    }
}
