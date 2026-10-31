import SwiftUI

struct DayDots: View {
    let mine: Bool
    let partner: Bool
    var onAccent = false

    var body: some View {
        HStack(spacing: 4) {
            Dot(colour: "NoteDotMine", ring: onAccent ? "OnAccent" : "Outline").opacity(mine ? 1 : 0)
            Dot(colour: "NoteDotPartner", ring: onAccent ? "OnAccent" : "Outline").opacity(partner ? 1 : 0)
        }
    }

    struct Dot: View {
        let colour: String
        var ring = "Outline"
        var size: CGFloat = 8

        var body: some View {
            Circle()
                .fill(Color(colour))
                .overlay(Circle().strokeBorder(Color(ring), lineWidth: 1.5))
                .frame(width: size, height: size)
        }
    }
}
