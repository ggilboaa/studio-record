import Foundation

class VirtualCameraManager: ObservableObject {
    @Published var isStreaming = false

    func toggle() { isStreaming.toggle() }
}
