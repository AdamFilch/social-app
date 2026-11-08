import SwiftUI

struct WaveformTrack: View {
    enum Mode {
        case recording(elapsed: TimeInterval, limit: TimeInterval)
        case playback(progress: Double?)
    }

    let levels: [Float]
    let mode: Mode
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            let inner = size.width - 20
            let low: CGFloat = 4
            let high = height * 0.75
            switch mode {
            case .recording(_, let limit):
                let slots = Int((limit / 0.19).rounded())
                let slot = inner / CGFloat(slots)
                for i in 0..<slots {
                    let x = 10 + slot * (CGFloat(i) + 0.5)
                    if i < levels.count {
                        let h = low + CGFloat(levels[i]) * (high - low)
                        context.fill(Path(roundedRect: CGRect(x: x - 1.5, y: (size.height - h) / 2, width: 3, height: h), cornerRadius: 1.5), with: .color(Color("TextPrimary")))
                    } else {
                        context.fill(Path(ellipseIn: CGRect(x: x - 2, y: size.height / 2 - 2, width: 4, height: 4)), with: .color(Color("TextSecondary").opacity(0.35)))
                    }
                }
            case .playback(let progress):
                let count = max(Int(inner / 5), 1)
                for i in 0..<count {
                    let from = levels.count * i / count
                    let to = max(levels.count * (i + 1) / count, from + 1)
                    let level = levels.isEmpty ? 0 : levels[from..<min(to, levels.count)].max() ?? 0
                    let h = low + CGFloat(level) * (high - low)
                    let x = 10 + inner * (CGFloat(i) + 0.5) / CGFloat(count)
                    context.fill(Path(roundedRect: CGRect(x: x - 1.5, y: (size.height - h) / 2, width: 3, height: h), cornerRadius: 1.5), with: .color(Color("TextPrimary")))
                }
                if let progress {
                    let x = 10 + inner * progress
                    context.fill(Path(roundedRect: CGRect(x: x - 1.25, y: 6, width: 2.5, height: size.height - 12), cornerRadius: 1.25), with: .color(Color("Danger")))
                }
            }
        }
        .frame(height: height)
        .background(Color("Background"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color("Outline"), lineWidth: 2))
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var label: String {
        if case .recording = mode { "Recording" } else { "Recorded sound" }
    }

    private var value: String {
        if case .recording(let elapsed, let limit) = mode { "\(Int(elapsed) / 2 * 2) of \(Int(limit)) seconds" } else { "" }
    }
}
