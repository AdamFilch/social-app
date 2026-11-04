import ARKit
import AVFoundation
import CoreImage
import Metal
import os

final class StickerCompositor: @unchecked Sendable {
    struct Placement {
        var corners: [CGPoint]
    }

    private struct Projection {
        let anchor: ARFaceAnchor
        let camera: ARCamera
        let raw: CGSize
        let toDisplay: CGAffineTransform
        let vertices: [SIMD3<Float>]
        let indices: [Int16]

        init(anchor: ARFaceAnchor, camera: ARCamera, raw: CGSize, toDisplay: CGAffineTransform) {
            self.anchor = anchor
            self.camera = camera
            self.raw = raw
            self.toDisplay = toDisplay
            vertices = anchor.geometry.vertices
            indices = anchor.geometry.triangleIndices
        }

        var eye: SIMD3<Float> {
            let c = camera.transform.columns.3
            return SIMD3(c.x, c.y, c.z)
        }

        func world(_ v: SIMD3<Float>, _ w: Float = 1) -> SIMD3<Float> {
            let p = anchor.transform * SIMD4(v, w)
            return SIMD3(p.x, p.y, p.z)
        }

        func project(_ point: SIMD3<Float>) -> CGPoint {
            let p = camera.projectPoint(world(point), orientation: .landscapeRight, viewportSize: raw)
            return CGPoint(x: p.x, y: raw.height - p.y).applying(toDisplay)
        }

        func facing(_ point: SIMD3<Float>, _ normal: SIMD3<Float>) -> Bool {
            simd_dot(world(normal, 0), eye - world(point)) > 0
        }

        func surface(_ triangle: Int, _ weights: SIMD3<Float>) -> (point: SIMD3<Float>, normal: SIMD3<Float>)? {
            guard triangle * 3 + 2 < indices.count else { return nil }
            let v = (0..<3).map { vertices[Int(indices[triangle * 3 + $0])] }
            let point = v[0] * weights.x + v[1] * weights.y + v[2] * weights.z
            let normal = simd_normalize(simd_cross(v[1] - v[0], v[2] - v[0]))
            return (point, simd_dot(normal, point) < 0 ? -normal : normal)
        }

        func hit(_ point: CGPoint) -> Anchor? {
            let screen = vertices.map(project)
            var best: (anchor: Anchor, distance: Float)?
            for triangle in 0..<indices.count / 3 {
                let a = screen[Int(indices[triangle * 3])]
                let b = screen[Int(indices[triangle * 3 + 1])]
                let c = screen[Int(indices[triangle * 3 + 2])]
                let area = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
                guard area != 0 else { continue }
                let wb = ((point.x - a.x) * (c.y - a.y) - (c.x - a.x) * (point.y - a.y)) / area
                let wc = ((b.x - a.x) * (point.y - a.y) - (point.x - a.x) * (b.y - a.y)) / area
                guard wb >= 0, wc >= 0, wb + wc <= 1 else { continue }
                let weights = SIMD3(Float(1 - wb - wc), Float(wb), Float(wc))
                guard let s = surface(triangle, weights), facing(s.point, s.normal) else { continue }
                let distance = simd_distance(world(s.point), eye)
                if best.map({ distance < $0.distance }) ?? true {
                    best = (.surface(triangle: triangle, weights: weights), distance)
                }
            }
            return best?.anchor
        }

        func onPlane(_ point: CGPoint) -> Anchor? {
            let z = vertices.map(\.z).max() ?? 0
            let plane = anchor.transform * simd_float4x4(SIMD4(1, 0, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, -1, 0, 0), SIMD4(0, 0, z, 1))
            let p = point.applying(toDisplay.inverted())
            guard let world = camera.unprojectPoint(CGPoint(x: p.x, y: raw.height - p.y), ontoPlane: plane, orientation: .landscapeRight, viewportSize: raw) else { return nil }
            let local = anchor.transform.inverse * SIMD4(world, 1)
            return .plane(SIMD3(local.x, local.y, z))
        }

        func quad(_ item: PlacedSticker) -> [CGPoint]? {
            let center: SIMD3<Float>
            let normal: SIMD3<Float>
            switch item.anchor {
            case .surface(let triangle, let weights):
                guard let s = surface(triangle, weights) else { return nil }
                (center, normal) = s
            case .plane(let point):
                (center, normal) = (point, SIMD3(0, 0, 1))
            }
            guard facing(center, normal) else { return nil }
            let cross = simd_cross(SIMD3(0, 1, 0), normal)
            let right0 = simd_length(cross) < 1e-3 ? SIMD3<Float>(1, 0, 0) : simd_normalize(cross)
            let up0 = simd_cross(normal, right0)
            let right = cos(item.rotation) * right0 + sin(item.rotation) * up0
            let up = cos(item.rotation) * up0 - sin(item.rotation) * right0
            let extent = item.image.extent
            let aspect = Float(extent.height / extent.width)
            let longest = StickerCompositor.faceSize * item.scale
            let width = aspect > 1 ? longest / aspect : longest
            let x = right * width / 2
            let y = up * width * aspect / 2
            return [center + x + y, center - x + y, center - x - y, center + x - y].map(project)
        }
    }

    private static let faceSize: Float = 0.06

    let preview = AVSampleBufferDisplayLayer()
    var onTracking: ((Bool) -> Void)?
    private let lock = NSLock()
    private var stickers: [PlacedSticker] = []
    private var placements: [UUID: Placement] = [:]
    private var projection: Projection?
    private var tracked = false
    private var display = CGSize(width: 720, height: 1280)
    private let context = MTLCreateSystemDefaultDevice().map { CIContext(mtlDevice: $0) } ?? CIContext()
    private var pools: [String: CVPixelBufferPool] = [:]
    private let log = Logger(subsystem: "com.adamfilchoir.buttercup", category: "StickerCompositor")
    private var timing = (frames: 0, total: 0.0, worst: 0.0)

    init() {
        preview.videoGravity = .resizeAspectFill
    }

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
                guard let c = placements[item.id]?.corners else { return false }
                let sides = (0..<4).map { i in
                    let a = c[i], b = c[(i + 1) % 4]
                    return (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
                }
                return sides.allSatisfy { $0 >= 0 } || sides.allSatisfy { $0 <= 0 }
            }?.id
        }
    }

    func pin(at point: CGPoint?) -> Anchor? {
        lock.withLock {
            guard let projection else { return nil }
            let point = point ?? projection.project(.zero)
            return projection.hit(point) ?? projection.onPlane(point)
        }
    }

    func render(_ buffer: CVPixelBuffer, face: ARFaceAnchor? = nil, camera: ARCamera? = nil, orientation: CGImagePropertyOrientation, mirrored: Bool = false) -> CVPixelBuffer {
        let start = DispatchTime.now().uptimeNanoseconds
        let raw = CIImage(cvPixelBuffer: buffer)
        let upright = raw.orientationTransform(for: orientation)
        let size = raw.extent.applying(upright).size
        let mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: size.width, ty: 0)
        let toDisplay = mirrored ? upright.concatenating(mirror) : upright
        let (layers, changed): ([(CIImage, [CGPoint], Bool)], Bool?) = lock.withLock {
            display = size
            if let face, let camera, face.isTracked {
                projection = Projection(anchor: face, camera: camera, raw: raw.extent.size, toDisplay: toDisplay)
            } else {
                projection = nil
            }
            placements = [:]
            var layers: [(CIImage, [CGPoint], Bool)] = []
            if let projection {
                for item in stickers {
                    guard let corners = projection.quad(item) else { continue }
                    placements[item.id] = Placement(corners: corners)
                    if case .text = item.sticker.kind {
                        layers.append((item.image, corners, true))
                    } else {
                        layers.append((item.image, corners, false))
                    }
                }
            }
            let now = projection != nil
            defer { tracked = now }
            return (layers, now != tracked ? now : nil)
        }
        if let changed { onTracking?(changed) }

        let visible = ProcessInfo.processInfo.thermalState == .critical ? [] : layers
        var overlay = CIImage.empty()
        var flipped = CIImage.empty()
        for (image, c, text) in visible {
            overlay = warp(image, text ? c : [c[1], c[0], c[3], c[2]]).composited(over: overlay)
            let m = c.map { $0.applying(mirror) }
            flipped = warp(image, [m[1], m[0], m[3], m[2]]).composited(over: flipped)
        }

        var output = buffer
        if !visible.isEmpty || mirrored, let target = makeBuffer(size) {
            context.render(overlay.composited(over: raw.transformed(by: toDisplay)), to: target)
            output = target
        }
        if let target = makeBuffer(size) {
            context.render(flipped.composited(over: raw.transformed(by: toDisplay).transformed(by: mirror)), to: target)
            show(target)
        }

        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        timing = (timing.frames + 1, timing.total + ms, max(timing.worst, ms))
        if timing.frames == 30 {
            let (average, worst) = (timing.total / 30, timing.worst)
            log.notice("Frame time avg \(average, format: .fixed(precision: 1)) ms, max \(worst, format: .fixed(precision: 1)) ms, \(visible.count) stickers")
            timing = (0, 0, 0)
        }
        return output
    }

    private func warp(_ image: CIImage, _ c: [CGPoint]) -> CIImage {
        image.applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": CIVector(cgPoint: c[0]),
            "inputTopRight": CIVector(cgPoint: c[1]),
            "inputBottomRight": CIVector(cgPoint: c[2]),
            "inputBottomLeft": CIVector(cgPoint: c[3])
        ])
    }

    private func show(_ buffer: CVPixelBuffer) {
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffer, formatDescriptionOut: &format)
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard let format, CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: buffer, formatDescription: format, sampleTiming: &timing, sampleBufferOut: &sample) == noErr, let sample else { return }
        sample.sampleAttachments[0][.displayImmediately] = true
        let renderer = preview.sampleBufferRenderer
        if renderer.status == .failed || renderer.requiresFlushToResumeDecoding { renderer.flush() }
        renderer.enqueue(sample)
    }

    private func makeBuffer(_ size: CGSize) -> CVPixelBuffer? {
        let key = "\(Int(size.width))x\(Int(size.height))"
        if pools[key] == nil {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
            pools[key] = pool
        }
        guard let pool = pools[key] else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }
}
