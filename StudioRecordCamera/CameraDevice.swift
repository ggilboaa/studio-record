import CoreMediaIO
import CoreVideo
import Foundation

class CameraDevice: NSObject, CMIOExtensionDeviceSource {
    private(set) var device: CMIOExtensionDevice!
    let streamSource: CameraStreamSource

    static let deviceID = UUID(uuidString: "4B4C1A2B-3C4D-5E6F-7A8B-9C0D1E2F3A4B")!
    static let streamID = UUID(uuidString: "1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D")!

    override init() {
        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreate(
            allocator: nil,
            codecType: kCVPixelFormatType_32BGRA,
            width: 1920, height: 1080,
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )

        let streamFormat = CMIOExtensionStreamFormat(
            formatDescription: formatDesc!,
            maxFrameDuration: CMTime(value: 1, timescale: 30),
            minFrameDuration: CMTime(value: 1, timescale: 30),
            validFrameDurations: nil
        )

        let source = CameraStreamSource(streamFormat: streamFormat)
        let stream = CMIOExtensionStream(
            localizedName: "Video",
            streamID: Self.streamID,
            direction: .source,
            clockType: .hostTime,
            source: source
        )
        self.streamSource = source

        super.init()

        device = CMIOExtensionDevice(
            localizedName: "Studio Record",
            deviceID: Self.deviceID,
            legacyDeviceID: nil,
            source: self
        )
        try? device.addStream(stream)
    }

    // MARK: — CMIOExtensionDeviceSource

    var availableProperties: Set<CMIOExtensionProperty> {
        [.deviceModel, .deviceTransportType]
    }

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let props = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceModel) { props.model = "Studio Record" }
        if properties.contains(.deviceTransportType) {
            props.transportType = 0x76697274  // 'virt' — virtual transport
        }
        return props
    }

    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {}
}
