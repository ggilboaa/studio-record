import CoreMediaIO
import CoreVideo
import CoreMedia
import Foundation

class CameraStreamSource: NSObject, CMIOExtensionStreamSource {
    var stream: CMIOExtensionStream!  // set by framework when CMIOExtensionStream is created

    let streamFormat: CMIOExtensionStreamFormat
    var activeFormatIndex: Int = 0

    private var timer: DispatchSourceTimer?
    private var frameNumber: UInt64 = 0
    private let frameQueue = DispatchQueue(label: "com.studiorecord.camera.frames", qos: .userInteractive)

    init(streamFormat: CMIOExtensionStreamFormat) {
        self.streamFormat = streamFormat
    }

    var formats: [CMIOExtensionStreamFormat] { [streamFormat] }

    var availableProperties: Set<CMIOExtensionProperty> {
        [.streamActiveFormatIndex, .streamFrameDuration]
    }

    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let props = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) { props.activeFormatIndex = 0 }
        if properties.contains(.streamFrameDuration) { props.frameDuration = CMTime(value: 1, timescale: 30) }
        return props
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        if let idx = streamProperties.activeFormatIndex { activeFormatIndex = idx }
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool { true }

    func startStream() throws {
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: frameQueue)
        t.schedule(deadline: .now(), repeating: 1.0 / 30.0, leeway: .milliseconds(2))
        t.setEventHandler { [weak self] in self?.sendFrame() }
        t.resume()
        timer = t
    }

    func stopStream() throws {
        timer?.cancel()
        timer = nil
    }

    private func sendFrame() {
        let width = 1920, height = 1080
        var pixelBuffer: CVPixelBuffer?
        let attrs: CFDictionary = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        guard CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer) == kCVReturnSuccess,
              let pb = pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(pb, [])
        if let base = CVPixelBufferGetBaseAddress(pb) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
            let hue = Double(frameNumber % 300) / 300.0
            let (r, g, b) = hsvToRgb(h: hue, s: 0.6, v: 0.7)
            for y in 0..<height {
                let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
                for x in 0..<width {
                    let p = x * 4
                    row[p + 0] = UInt8(b * 255)
                    row[p + 1] = UInt8(g * 255)
                    row[p + 2] = UInt8(r * 255)
                    row[p + 3] = 255
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])

        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb, formatDescriptionOut: &formatDesc)
        guard let desc = formatDesc else { return }

        let hostTime = CMClockGetTime(CMClockGetHostTimeClock())
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: hostTime,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil, imageBuffer: pb,
            formatDescription: desc, sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard let sb = sampleBuffer else { return }

        let nanos = UInt64(max(0, hostTime.seconds) * 1_000_000_000)
        stream.send(sb, discontinuity: [], hostTimeInNanoseconds: nanos)
        frameNumber += 1
    }

    private func hsvToRgb(h: Double, s: Double, v: Double) -> (Double, Double, Double) {
        let i = Int(h * 6), f = h * 6 - Double(i)
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        switch i % 6 {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }
}
