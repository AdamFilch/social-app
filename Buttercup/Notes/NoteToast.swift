import SwiftUI

struct NoteToast: View {
    let message: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
            Text(message)
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(Color("TextPrimary"))
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
        .background(Capsule().fill(Color("Surface")))
        .overlay(Capsule().strokeBorder(Color("Outline"), lineWidth: 2))
        .padding(.horizontal, 20)
        .accessibilityHidden(true)
    }
}
