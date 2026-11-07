import SwiftUI

struct Doodle: View {
    let name: String
    var size: CGFloat = 34

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
