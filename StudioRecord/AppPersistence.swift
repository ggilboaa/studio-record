import Foundation
import CoreGraphics

enum AppPersistence {
    private static let ud = UserDefaults.standard

    // MARK: - Active scene
    static func save(scene: AppScene) {
        ud.set(scene.rawValue, forKey: "activeScene")
    }
    static func loadScene() -> AppScene {
        AppScene(rawValue: ud.integer(forKey: "activeScene")) ?? .camera
    }

    // MARK: - Camera
    static func save(cameraID: String, isMirrored: Bool) {
        ud.set(cameraID,    forKey: "cameraID")
        ud.set(isMirrored,  forKey: "cameraMirrored")
    }
    static func loadCameraID() -> String? { ud.string(forKey: "cameraID") }
    static func loadCameraMirrored() -> Bool { ud.bool(forKey: "cameraMirrored") }

    // MARK: - Floating circle (per-scene key: "circle2" or "circle3")
    static func save(circle: FloatingCircleState, key: String) {
        ud.set(Double(circle.position.x), forKey: "\(key).x")
        ud.set(Double(circle.position.y), forKey: "\(key).y")
        ud.set(Double(circle.size),       forKey: "\(key).size")
        ud.set(circle.isLocked,           forKey: "\(key).locked")
        ud.set(circle.shape.rawValue,     forKey: "\(key).shape")
    }
    static func load(circle: FloatingCircleState, key: String) {
        let x    = ud.double(forKey: "\(key).x")
        let y    = ud.double(forKey: "\(key).y")
        let size = ud.double(forKey: "\(key).size")
        if x != 0 || y != 0 { circle.position = CGPoint(x: x, y: y) }
        if size > 0 { circle.size = CGFloat(size) }
        circle.isLocked = ud.bool(forKey: "\(key).locked")
        circle.shape    = CircleShape(rawValue: ud.string(forKey: "\(key).shape") ?? "") ?? .circle
    }

    // MARK: - Browser URL
    static func save(browserURL: String) { ud.set(browserURL, forKey: "browserURL") }
    static func loadBrowserURL() -> String? { ud.string(forKey: "browserURL") }

    // MARK: - Last captured window
    static func save(windowBundleID: String?, windowTitle: String?) {
        ud.set(windowBundleID, forKey: "lastWindowBundleID")
        ud.set(windowTitle,    forKey: "lastWindowTitle")
    }
    static func loadLastWindowBundleID() -> String? { ud.string(forKey: "lastWindowBundleID") }
    static func loadLastWindowTitle()    -> String? { ud.string(forKey: "lastWindowTitle") }

    // MARK: - Standby image path
    static func save(standbyImagePath: String?) { ud.set(standbyImagePath, forKey: "standbyImagePath") }
    static func loadStandbyImagePath() -> String? { ud.string(forKey: "standbyImagePath") }

    // MARK: - Floating panel origin
    static func save(panelOrigin: CGPoint) {
        ud.set(Double(panelOrigin.x), forKey: "panelX")
        ud.set(Double(panelOrigin.y), forKey: "panelY")
    }
    static func loadPanelOrigin() -> CGPoint? {
        let x = ud.double(forKey: "panelX")
        let y = ud.double(forKey: "panelY")
        guard x != 0 || y != 0 else { return nil }
        return CGPoint(x: x, y: y)
    }
}
