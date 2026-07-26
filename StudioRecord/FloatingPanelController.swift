import AppKit
import SwiftUI

class FloatingPanelController: NSObject, ObservableObject, NSWindowDelegate {
    private var panel: NSPanel?

    func setup(
        cameraManager:    CameraManager,
        recordingManager: RecordingManager,
        sceneManager:     SceneManager,
        virtualCamera:    VirtualCameraManager,
        circleState:      FloatingCircleState,
        webNav:           WebNavState
    ) {
        guard panel == nil else { return }

        let view = FloatingPanelView(
            cameraManager:    cameraManager,
            recordingManager: recordingManager,
            sceneManager:     sceneManager,
            virtualCamera:    virtualCamera,
            circleState:      circleState,
            webNav:           webNav
        )

        let hosting = NSHostingView(rootView: view)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 110),
            styleMask:   [.nonactivatingPanel, .closable, .fullSizeContentView],
            backing:     .buffered,
            defer:       false
        )
        p.level                        = .floating
        p.collectionBehavior           = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground  = true
        p.hidesOnDeactivate            = false
        p.isFloatingPanel              = true
        p.isOpaque                     = false
        p.backgroundColor              = .clear
        p.contentView                  = hosting
        p.delegate                     = self
        p.isReleasedWhenClosed         = false
        p.title                        = "Studio Record"

        if let origin = AppPersistence.loadPanelOrigin() {
            p.setFrameOrigin(origin)
        } else if let screen = NSScreen.main {
            // Default: top-center
            let x = (screen.frame.width - 480) / 2
            let y = screen.frame.height - 120
            p.setFrameOrigin(CGPoint(x: x, y: y))
        }

        self.panel = p
        p.orderFront(nil)
    }

    func toggle() {
        guard let p = panel else { return }
        if p.isVisible { p.orderOut(nil) } else { p.orderFront(nil) }
    }

    // MARK: - NSWindowDelegate
    func windowDidMove(_ notification: Notification) {
        guard let p = panel else { return }
        AppPersistence.save(panelOrigin: p.frame.origin)
    }
}
