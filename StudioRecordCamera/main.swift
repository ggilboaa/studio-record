import CoreMediaIO
import Foundation

let provider = CameraProvider()
CMIOExtensionProvider.startService(provider: provider.provider)
