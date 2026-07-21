import CoreMediaIO
import Foundation

class CameraProvider: NSObject, CMIOExtensionProviderSource {
    private(set) var provider: CMIOExtensionProvider!
    private let cameraDevice: CameraDevice

    override init() {
        cameraDevice = CameraDevice()
        super.init()
        provider = CMIOExtensionProvider(source: self, clientQueue: nil)
        try? provider.addDevice(cameraDevice.device)
    }

    func connect(to client: CMIOExtensionClient) throws {}
    func disconnect(from client: CMIOExtensionClient) {}

    var availableProperties: Set<CMIOExtensionProperty> {
        [.providerName, .providerManufacturer]
    }

    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let props = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerName)         { props.name = "Studio Record" }
        if properties.contains(.providerManufacturer) { props.manufacturer = "Studio Record" }
        return props
    }

    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {}
}
