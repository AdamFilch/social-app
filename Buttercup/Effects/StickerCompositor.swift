import ARKit
import CoreImage
import Metal

final class StickerCompositor: @unchecked Sendable {
    struct Placement {
        var center: CGPoint
        var size: CGSize
        var angle: CGFloat
    }

    private struct Projection {
        let anchor: ARFaceAnchor
        let camera: ARCamera
        let raw: CGSize
        let toDisplay: CGAffineTransform

        func project(_ point: SIMD3<Float>) -> CGPoint {
            let world = anchor.transform * SIMD4(point, 1)
            let p = camera.projectPoint(SIMD3(world.x, world.y, world.z), orientation: .landscapeRight, viewportSize: raw)
            return CGPoint(x: p.x, y: raw.height - p.y).applying(toDisplay)
        }

        var frame: (pixelsPerMeter: CGFloat, roll: CGFloat) {
            let center = project(.zero)
            let side = project(SIMD3(0.1, 0, 0))
            let dx = side.x - center.x, dy = side.y - center.y
            return (hypot(dx, dy) / 0.1, atan2(dy, dx))
        }
    }

    private static let faceSize: CGFloat = 0.06
    private static let snapDistance: Float = 0.03

    private let lock = NSLock()
    private var stickers: [PlacedSticker] = []
    private var placements: [UUID: Placement] = [:]
    private var projection: Projection?
    private var display = CGSize(width: 720, height: 1280)
    private let context = MTLCreateSystemDefaultDevice().map { CIContext(mtlDevice: $0) } ?? CIContext()
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero

    var items: [PlacedSticker] {
        get { lock.withLock { stickers } }
        set { lock.withLock { stickers = newValue } }
    }

    var displaySize: CGSize { lock.withLock { display } }

    func placement(_ id: UUID) -> Placement? {
        lock.withLock { placements[id] }
    }

    func hit(_ point: CGPoint) -> UUID? {
        lock.withLock {
            stickers.reversed().first { item in
                guard let p = placements[item.id] else { return false }
                let local = CGPoint(x: point.x - p.center.x, y: point.y - p.center.y)
                    .applying(CGAffineTransform(rotationAngle: -p.angle))
                return abs(local.x) <= p.size.width / 2 && abs(local.y) <= p.size.height / 2
            }?.id
        }
    }

    func pin(at point: CGPoint?) -> (vertexIndex: Int?, offset: SIMD2<Float>, roll: Float) {
        lock.withLock {
            guard let projection else {
                let p = point ?? CGPoint(x: display.width / 2, y: display.height / 2)
                return (nil, SIMD2(Float(p.x), Float(p.y)), 0)
            }
            let frame = projection.frame
            let point = point ?? projection.project(.zero)
            var best = 0
            var bestDistance = CGFloat.infinity
            var bestPoint = CGPoint.zero
            for (index, vertex) in projection.anchor.geometry.vertices.enumerated() {
                let p = projection.project(vertex)
                let distance = hypot(p.x - point.x, p.y - point.y)
                if distance < bestDistance {
                    best = index
                    bestDistance = distance
                    bestPoint = p
                }
            }
            let delta = CGPoint(x: point.x - bestPoint.x, y: point.y - bestPoint.y)
                .applying(CGAffineTransform(rotationAngle: -frame.roll))
            var offset = SIMD2(Float(delta.x), Float(delta.y)) / Float(frame.pixelsPerMeter)
            if simd_length(offset) > Self.snapDistance { offset = .zero }
            return (best, offset, Float(frame.roll))
        }
    }

    func render(_ buffer: CVPixelBuffer, face: ARFaceAnchor? = nil, camera: ARCamera? = nil, orientation: CGImagePropertyOrientation) -> CVPixelBuffer {
        let raw = CIImage(cvPixelBuffer: buffer)
        let toDisplay = raw.orientationTransform(for: orientation)
        let layers: [(CIImage, Placement)] = lock.withLock {
            display = raw.extent.applying(toDisplay).size
            if let face, let camera, face.isTracked {
                projection = Projection(anchor: face, camera: camera, raw: raw.extent.size, toDisplay: toDisplay)
            }
            placements = [:]
            for item in stickers {
                placements[item.id] = place(item)
            }
            return stickers.compactMap { item in placements[item.id].map { (item.image, $0) } }
        }
        guard !layers.isEmpty, ProcessInfo.processInfo.thermalState != .critical else { return buffer }
        var overlay = CIImage.empty()
        for (image, p) in layers {
            let extent = image.extent
            let scale = p.size.width / extent.width
            let transform = CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(rotationAngle: p.angle))
                .concatenating(CGAffineTransform(translationX: p.center.x, y: p.center.y))
            overlay = image.transformed(by: transform).composited(over: overlay)
        }
        let output = overlay.transformed(by: toDisplay.inverted()).composited(over: raw)
        guard let target = makeBuffer(raw.extent.size) else { return buffer }
        context.render(output, to: target)
        return target
    }

    private func place(_ item: PlacedSticker) -> Placement? {
        let extent = item.image.extent
        let aspect = extent.height / extent.width
        guard let index = item.vertexIndex else {
            let width = min(display.width, display.height) * 0.3 * CGFloat(item.scale)
            return Placement(center: CGPoint(x: CGFloat(item.offset.x), y: CGFloat(item.offset.y)), size: CGSize(width: width, height: width * aspect), angle: CGFloat(item.rotation))
        }
        guard let projection, index < projection.anchor.geometry.vertices.count else { return nil }
        let frame = projection.frame
        let vertex = projection.project(projection.anchor.geometry.vertices[index])
        let offset = CGPoint(x: CGFloat(item.offset.x), y: CGFloat(item.offset.y))
            .applying(CGAffineTransform(rotationAngle: frame.roll))
        let longest = Self.faceSize * frame.pixelsPerMeter * CGFloat(item.scale)
        let width = aspect > 1 ? longest / aspect : longest
        return Placement(
            center: CGPoint(x: vertex.x + offset.x * frame.pixelsPerMeter, y: vertex.y + offset.y * frame.pixelsPerMeter),
            size: CGSize(width: width, height: width * aspect),
            angle: frame.roll + CGFloat(item.rotation)
        )
    }

    private func makeBuffer(_ size: CGSize) -> CVPixelBuffer? {
        if pool == nil || poolSize != size {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            pool = nil
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
            poolSize = size
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }
}
