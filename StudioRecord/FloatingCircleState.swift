import Foundation
import CoreGraphics

enum CircleShape: String {
    case circle
    case roundedRect
}

class FloatingCircleState: ObservableObject {
    // Normalized (0.0–1.0) relative to container — immune to resize/scene-switch
    @Published var normX:    CGFloat = 0.20
    @Published var normY:    CGFloat = 0.75
    @Published var normSize: CGFloat = 0.18
    @Published var isLocked: Bool = false
    @Published var isHidden: Bool = false
    @Published var shape:    CircleShape = .circle

    func absWidth(containerW w: CGFloat) -> CGFloat {
        let s = normSize * w
        return shape == .roundedRect ? s * 1.33 : s
    }
    func absHeight(containerW w: CGFloat) -> CGFloat { normSize * w }
}
