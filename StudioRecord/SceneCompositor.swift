import Foundation
import CoreImage
import AVFoundation
import CoreMedia
import CoreVideo
import AppKit

/// Composites the active scene (camera / window+circle / browser+circle) into
/// 1920×1080 BGRA CMSampleBuffers for recording.
class SceneCompositor: ObservableObject {
    weak var sceneManager:  SceneManager?
    weak var circleState2:  FloatingCircleState?
    weak var circleState3:  FloatingCircleState?
    weak var cameraManager: CameraManager?

    var composedFrameHandler: ((CMSampleBuffer) -> Void)?

    private var latestWindowBuffer:  CVPixelBuffer?
    private var latestBrowserCGImage: CGImage?

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let queue = DispatchQueue(label: "com.studiorecord.compositor", qos: .userInteractive)

    // MARK: - Feed inputs

    func processCameraFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts      = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let scene    = sceneManager?.activeScene
        let mirrored = cameraManager?.isMirrored ?? false
        let s2 = circleState2.map { CircleSnap($0) }
        let s3 = circleState3.map { CircleSnap($0) }

        queue.async { [weak self] in
            self?.compose(scene: scene, camPB: pixelBuffer,
                          mirrored: mirrored, s2: s2, s3: s3, pts: pts)
        }
    }

    func processWindowFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        queue.async { [weak self] in self?.latestWindowBuffer = pb }
    }

    func processBrowserFrame(_ cgImage: CGImage) {
        queue.async { [weak self] in self?.latestBrowserCGImage = cgImage }
    }

    // MARK: - Composition

    private func compose(scene: AppScene?, camPB: CVPixelBuffer, mirrored: Bool,
                         s2: CircleSnap?, s3: CircleSnap?, pts: CMTime) {
        let W: CGFloat = 1920, H: CGFloat = 1080
        var cam = CIImage(cvPixelBuffer: camPB)
        if mirrored { cam = cam.hFlipped() }

        switch scene {
        case .camera:
            emit(cam.scaledToFill(W, H), W: W, H: H, pts: pts)

        case .window:
            let bg = latestWindowBuffer.map { CIImage(cvPixelBuffer: $0).scaledToFill(W, H) }
                  ?? CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
            emit(overlay(bg: bg, cam: cam, snap: s2, W: W, H: H), W: W, H: H, pts: pts)

        case .browser:
            let bg = latestBrowserCGImage.map { CIImage(cgImage: $0).scaledToFill(W, H) }
                  ?? CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
            emit(overlay(bg: bg, cam: cam, snap: s3, W: W, H: H), W: W, H: H, pts: pts)

        case .standby, .none:
            break
        }
    }

    private func overlay(bg: CIImage, cam: CIImage, snap: CircleSnap?,
                         W: CGFloat, H: CGFloat) -> CIImage {
        guard let snap, !snap.isHidden else { return bg }

        let absSize = snap.normSize * W
        let absW    = snap.shape == .roundedRect ? absSize * 1.33 : absSize
        let absH    = absSize
        // CoreImage Y=0 is bottom; normY=0 is top → flip
        let cx = snap.normX * W
        let cy = (1.0 - snap.normY) * H

        // Aspect-fill camera into circle rect
        let scale = max(absW / cam.extent.width, absH / cam.extent.height)
        let sw = cam.extent.width * scale, sh = cam.extent.height * scale
        var camFit = cam
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: -(sw - absW) / 2,
                                               y: -(sh - absH) / 2))
            .cropped(to: CGRect(x: 0, y: 0, width: absW, height: absH))

        // Apply clip mask
        let cr = snap.shape == .roundedRect ? min(absW, absH) * 0.12 : 0.0
        if let mask = makeMask(w: absW, h: absH, cornerRadius: cr) {
            camFit = camFit.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputMaskImageKey:       mask,
                kCIInputBackgroundImageKey: CIImage.empty()
            ])
        }

        return camFit
            .transformed(by: CGAffineTransform(translationX: cx - absW / 2, y: cy - absH / 2))
            .composited(over: bg)
            .cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
    }

    private func makeMask(w: CGFloat, h: CGFloat, cornerRadius: CGFloat) -> CIImage? {
        guard let ctx = CGContext(data: nil, width: Int(w), height: Int(h),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)
        else { return nil }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(gray: 1, alpha: 1)
        if cornerRadius > 0 {
            ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                               cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        } else {
            ctx.addEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        ctx.fillPath()
        return ctx.makeImage().map { CIImage(cgImage: $0) }
    }

    private func emit(_ image: CIImage, W: CGFloat, H: CGFloat, pts: CMTime) {
        let rect = CGRect(x: 0, y: 0, width: W, height: H)
        let attrs: CFDictionary = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey:           Int(W),
            kCVPixelBufferHeightKey:          Int(H),
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        var pb: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(W), Int(H),
                                  kCVPixelFormatType_32BGRA, attrs, &pb) == kCVReturnSuccess,
              let pixelBuffer = pb else { return }
        ciContext.render(image.cropped(to: rect), to: pixelBuffer)

        var fd: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer,
                                                     formatDescriptionOut: &fd)
        guard let formatDesc = fd else { return }

        var timing = CMSampleTimingInfo(duration: .invalid,
                                        presentationTimeStamp: pts,
                                        decodeTimeStamp: .invalid)
        var sb: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixelBuffer,
                                                 formatDescription: formatDesc,
                                                 sampleTiming: &timing, sampleBufferOut: &sb)
        if let sb { composedFrameHandler?(sb) }
    }
}

// MARK: - Private helpers

private struct CircleSnap {
    let normX, normY, normSize: CGFloat
    let shape: CircleShape
    let isHidden: Bool
    init(_ s: FloatingCircleState) {
        normX = s.normX; normY = s.normY; normSize = s.normSize
        shape = s.shape; isHidden = s.isHidden
    }
}

private extension CIImage {
    func hFlipped() -> CIImage {
        transformed(by: CGAffineTransform(scaleX: -1, y: 1)
            .translatedBy(x: -extent.width, y: 0))
    }
    func scaledToFill(_ W: CGFloat, _ H: CGFloat) -> CIImage {
        let s = max(W / extent.width, H / extent.height)
        let sw = extent.width * s, sh = extent.height * s
        return transformed(by: CGAffineTransform(scaleX: s, y: s))
            .transformed(by: CGAffineTransform(translationX: -(sw - W) / 2,
                                               y: -(sh - H) / 2))
            .cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
    }
}
