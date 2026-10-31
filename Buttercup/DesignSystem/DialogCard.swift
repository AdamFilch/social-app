import SwiftUI

struct DialogCard<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isPresented {
                Color.black
                    .opacity(colorScheme == .dark ? 0.6 : 0.42)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .accessibilityHidden(true)
                    .transition(.opacity)
                VStack(spacing: 14) { content }
                    .padding(16)
                    .background(Color("Surface"), in: .rect(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Color("Outline"), lineWidth: 2.5))
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { isPresented = false }
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
            }
        }
        .animation(.easeOut(duration: isPresented ? 0.2 : 0.15), value: isPresented)
    }
}
