import AppKit
import SwiftUI

class FloatingPanelController: NSObject, ObservableObject, NSWindowDelegate {
    private var panel: NSPanel?

    func setup(
        cameraManager:    CameraManager,
        recordingManager: RecordingManager,
        sceneManager:     SceneManager,
        virtualCamera:    VirtualCameraManager,
        circleState2:     FloatingCircleState,
        circleState3:     FloatingCircleState,
        webNav:           WebNavState
    ) {
        guard panel == nil else { return }

        let view = FloatingPanelView(
            cameraManager:    cameraManager,
            recordingManager: recordingManager,
            sceneManager:     sceneManager,
            virtualCamera:    virtualCamera,
            circleState2:     circleState2,
            circleState3:     circleState3,
            webNav:           webNav
        )

        let hosting = NSHostingView(rootView: view)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 48),
            styleMask:   [.nonactivatingPanel, .hudWindow, .closable],
            backing:     .buffered,
            defer:       false
        )
        p.level                        = .floating
        p.collectionBehavior           = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground  = true
        p.hidesOnDeactivate            = false
        p.isFloatingPanel              = true
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
