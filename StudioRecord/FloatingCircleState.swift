import Foundation
import CoreGraphics

enum CircleShape: String {
    case circle
    case roundedRect
}

class FloatingCircleState: ObservableObject {
    @Published var position: CGPoint = CGPoint(x: 200, y: 160)
    @Published var size:     CGFloat = 150
    @Published var isLocked: Bool = false
    @Published var isHidden: Bool = false
    @Published var shape:    CircleShape = .circle

    var frameWidth:  CGFloat { shape == .roundedRect ? size * 1.33 : size }
    var frameHeight: CGFloat { size }
}
