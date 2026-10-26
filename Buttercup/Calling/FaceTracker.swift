import ARKit
import os

protocol FaceTracker: AnyObject {
    var onFrame: ((CVPixelBuffer, ARFaceAnchor?, TimeInterval) -> Void)? { get set }
    func start()
    func stop()
}

final class ARKitFaceTracker: NSObject, FaceTracker, ARSessionDelegate, @unchecked Sendable {
    var onFrame: ((CVPixelBuffer, ARFaceAnchor?, TimeInterval) -> Void)?
    private let session = ARSession()
    private let log = Logger(subsystem: "com.adamfilchoir.buttercup", category: "FaceTracker")
    private var thermal: NSObjectProtocol?

    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = DispatchQueue(label: "FaceTracker")
        let log = log
        log.notice("Thermal state \(ProcessInfo.processInfo.thermalState.rawValue)")
        thermal = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { _ in
            log.notice("Thermal state \(ProcessInfo.processInfo.thermalState.rawValue)")
        }
    }

    func start() {
        let config = ARFaceTrackingConfiguration()
        if let format = ARFaceTrackingConfiguration.supportedVideoFormats.first(where: {
            $0.imageResolution == CGSize(width: 1280, height: 720) && $0.framesPerSecond == 30
        }) {
            config.videoFormat = format
        }
        config.isLightEstimationEnabled = false
        config.maximumNumberOfTrackedFaces = 1
        session.run(config)
        let size = config.videoFormat.imageResolution
        log.notice("AR session running \(Int(size.width))x\(Int(size.height)) @ \(config.videoFormat.framesPerSecond) fps, light estimation \(config.isLightEstimationEnabled ? "on" : "off")")
    }

    func stop() {
        session.pause()
        log.notice("AR session paused")
    }

    func session(_: ARSession, didUpdate frame: ARFrame) {
        let face = frame.anchors.lazy.compactMap { $0 as? ARFaceAnchor }.first
        onFrame?(frame.capturedImage, face, frame.timestamp)
    }
}
