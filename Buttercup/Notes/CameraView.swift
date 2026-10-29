import AVFoundation
import SwiftUI

@MainActor
@Observable
final class Camera: NSObject {
    enum Status { case unknown, ready, denied, unavailable }

    var status: Status = .unknown
    var isInterrupted = false
    @ObservationIgnored nonisolated(unsafe) let session = AVCaptureSession()
    @ObservationIgnored nonisolated(unsafe) private let output = AVCapturePhotoOutput()
    @ObservationIgnored nonisolated(unsafe) private var input: AVCaptureDeviceInput?
    @ObservationIgnored private let queue = DispatchQueue(label: "camera")
    @ObservationIgnored private var onCapture: ((UIImage) -> Void)?
    @ObservationIgnored private var zoomBase: CGFloat = 1
    @ObservationIgnored private var zoomFactor: CGFloat = 1
    #if DEBUG && targetEnvironment(simulator)
    var still: UIImage?
    #endif

    override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isInterrupted = true }
        }
        NotificationCenter.default.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isInterrupted = false }
        }
    }

    func start(front: Bool) async {
        var access = AVCaptureDevice.authorizationStatus(for: .video)
        if access == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            access = AVCaptureDevice.authorizationStatus(for: .video)
        }
        switch access {
        case .authorized: break
        case .denied: status = .denied; return
        default: status = .unavailable; return
        }
        #if DEBUG && targetEnvironment(simulator)
        if UserDefaults.standard.bool(forKey: "notePhotoStub") {
            still = await Self.testClipFrame()
            status = still == nil ? .unavailable : .ready
            return
        }
        #endif
        zoomBase = 1
        zoomFactor = 1
        let running = await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.run(front: front)) }
        }
        status = running ? .ready : .unavailable
    }

    func stop() {
        queue.async { self.halt() }
    }

    func zoom(_ magnification: CGFloat) {
        zoomFactor = min(max(zoomBase * magnification, 1), 5)
        let factor = zoomFactor
        queue.async { self.apply(zoom: factor) }
    }

    func endZoom() {
        zoomBase = zoomFactor
    }

    func capture(flash: Bool, _ completion: @escaping (UIImage) -> Void) {
        guard onCapture == nil, status == .ready else { return }
        onCapture = completion
        #if DEBUG && targetEnvironment(simulator)
        if let still {
            finish(still)
            return
        }
        #endif
        queue.async { self.shoot(flash: flash) }
    }

    static func square(_ image: UIImage) -> UIImage {
        let side: CGFloat = 1000
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let scale = side / min(image.size.width, image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
    }

    private func finish(_ image: UIImage) {
        onCapture?(Self.square(image))
        onCapture = nil
    }

    nonisolated private func run(front: Bool) -> Bool {
        let position: AVCaptureDevice.Position = front ? .front : .back
        if input?.device.position != position {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return false }
            session.beginConfiguration()
            session.sessionPreset = .photo
            if let input { session.removeInput(input) }
            guard session.canAddInput(newInput) else {
                session.commitConfiguration()
                return false
            }
            session.addInput(newInput)
            if session.outputs.isEmpty, session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            input = newInput
        }
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = front
            }
        }
        apply(zoom: 1)
        if !session.isRunning { session.startRunning() }
        return true
    }

    nonisolated private func halt() {
        if session.isRunning { session.stopRunning() }
    }

    nonisolated private func apply(zoom factor: CGFloat) {
        guard let device = input?.device, (try? device.lockForConfiguration()) != nil else { return }
        device.videoZoomFactor = min(factor, device.maxAvailableVideoZoomFactor)
        device.unlockForConfiguration()
    }

    nonisolated private func shoot(flash: Bool) {
        let settings = AVCapturePhotoSettings()
        if flash, output.supportedFlashModes.contains(.on) { settings.flashMode = .on }
        output.capturePhoto(with: settings, delegate: self)
    }

    #if DEBUG && targetEnvironment(simulator)
    private static func testClipFrame() async -> UIImage? {
        guard let url = Bundle.main.url(forResource: "test-clip", withExtension: "mp4") else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        guard let frame = try? await generator.image(at: .zero).image else { return nil }
        return UIImage(cgImage: frame)
    }
    #endif
}

extension Camera: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            guard let data, let image = UIImage(data: data) else {
                self.onCapture = nil
                return
            }
            self.finish(image)
        }
    }
}

struct CameraView: View {
    let camera: Camera

    var body: some View {
        viewfinder
            .opacity(camera.isInterrupted ? 0.4 : 1)
            .animation(.easeOut(duration: 0.15), value: camera.isInterrupted)
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { camera.zoom($0.magnification) }
                    .onEnded { _ in camera.endZoom() }
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var viewfinder: some View {
        #if DEBUG && targetEnvironment(simulator)
        if let still = camera.still {
            Image(uiImage: still)
                .resizable()
                .scaledToFill()
        } else {
            PreviewLayer(session: camera.session)
        }
        #else
        PreviewLayer(session: camera.session)
        #endif
    }
}

private struct PreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
