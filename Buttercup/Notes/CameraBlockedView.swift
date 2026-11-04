import SwiftUI

struct CameraBlockedView: View {
    enum Reason { case denied, unavailable }

    let reason: Reason
    let partnerName: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 44))
                .foregroundStyle(Color("TextSecondary"))
                .accessibilityHidden(true)
            Text(reason == .denied ? "Camera is off for buttercup" : "No camera available")
                .font(.headline)
                .foregroundStyle(Color("TextPrimary"))
            if reason == .denied {
                Text("Turn it on in Settings to take a photo for \(partnerName).")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("TextSecondary"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(PillButtonStyle(kind: .secondary, height: 44))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Surface"))
    }
}
