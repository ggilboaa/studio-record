import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var cameraManager    = CameraManager()
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var sceneManager     = SceneManager()
    @StateObject private var screenCapture    = ScreenCaptureManager()
    @StateObject private var circleState2     = FloatingCircleState()
    @StateObject private var circleState3     = FloatingCircleState()
    @StateObject private var webNav           = WebNavState()
    @StateObject private var standbyState     = StandbyState()
    @StateObject private var virtualCamera    = VirtualCameraManager()
    @StateObject private var appSettings      = AppSettings()
    @StateObject private var panelController  = FloatingPanelController()

    @State private var showWindowPicker  = false
    @State private var browserURLInput   = ""
    @State private var showSettings      = false

    var body: some View {
        VStack(spacing: 0) {
            ControlBarView(
                cameraManager:    cameraManager,
                recordingManager: recordingManager,
                sceneManager:     sceneManager,
                circleState:      activeCircleState,
                webNav:           webNav,
                standbyState:     standbyState,
                virtualCamera:    virtualCamera,
                screenCapture:    screenCapture,
                showWindowPicker: $showWindowPicker,
                browserURLInput:  $browserURLInput,
                showSettings:     $showSettings
            )
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // All scenes stay alive — prevents WebView reload on scene switch.
            // Aspect ratio locked to 16:9 so content never gets cropped.
            ZStack {
                Scene1View(cameraManager: cameraManager)
                    .opacity(sceneManager.activeScene == .camera ? 1 : 0)
                    .allowsHitTesting(sceneManager.activeScene == .camera)
                Scene2View(screenCapture: screenCapture, showPicker: $showWindowPicker)
                    .opacity(sceneManager.activeScene == .window ? 1 : 0)
                    .allowsHitTesting(sceneManager.activeScene == .window)
                Scene3View(nav: webNav)
                    .opacity(sceneManager.activeScene == .browser ? 1 : 0)
                    .allowsHitTesting(sceneManager.activeScene == .browser)
                Scene4View(state: standbyState)
                    .opacity(sceneManager.activeScene == .standby ? 1 : 0)
                    .allowsHitTesting(sceneManager.activeScene == .standby)
            }
            .animation(.easeInOut(duration: 0.22), value: sceneManager.activeScene)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if sceneManager.activeScene.hasFloatingCircle, !activeCircleState.isHidden {
                    FloatingCameraCircle(
                        session:    cameraManager.session,
                        isMirrored: cameraManager.isMirrored,
                        state:      activeCircleState
                    )
                }
            }
        }
        .onAppear { setup() }
        .onDisappear { teardown() }
        // ── Notification observers ──────────────────────────────────────
        .onReceive(nc.publisher(for: .studioSwitchScene)) { note in
            if let scene = note.object as? AppScene { sceneManager.setScene(scene) }
        }
        .onReceive(nc.publisher(for: .studioToggleCircle))    { _ in activeCircleState.isHidden.toggle() }
        .onReceive(nc.publisher(for: .studioToggleMic))       { _ in cameraManager.toggleMic() }
        .onReceive(nc.publisher(for: .studioToggleRecording)) { _ in
            if recordingManager.isRecording { recordingManager.stopRecording() }
            else { recordingManager.startRecording() }
        }
        .onReceive(nc.publisher(for: .studioToggleStandby))   { _ in sceneManager.toggleStandby() }
        .onReceive(nc.publisher(for: .studioToggleBroadcast)) { _ in virtualCamera.toggle() }
        .onReceive(nc.publisher(for: .studioTogglePanel))     { _ in panelController.toggle() }
        // ── Persist scene changes ────────────────────────────────────────
        .onChange(of: sceneManager.activeScene) { _, scene in
            AppPersistence.save(scene: scene)
        }
        .onChange(of: webNav.displayURL) { _, url in
            if !url.isEmpty { AppPersistence.save(browserURL: url) }
        }
        .onChange(of: screenCapture.selectedWindow?.windowID) { _, _ in
            AppPersistence.save(
                windowBundleID: screenCapture.selectedWindow?.owningApplication?.bundleIdentifier,
                windowTitle:    screenCapture.selectedWindow?.title
            )
        }
        .onChange(of: cameraManager.selectedCamera?.uniqueID) { _, _ in
            if let cam = cameraManager.selectedCamera {
                AppPersistence.save(cameraID: cam.uniqueID,
                                    isMirrored: cameraManager.isMirrored)
            }
        }
        .onChange(of: cameraManager.isMirrored) { _, mirrored in
            if let cam = cameraManager.selectedCamera {
                AppPersistence.save(cameraID: cam.uniqueID, isMirrored: mirrored)
            }
        }
        .onChange(of: appSettings.saveFolder) { _, folder in
            recordingManager.saveFolder = folder
        }
        .onChange(of: appSettings.separateAudioTracks) { _, separate in
            recordingManager.separateAudioTracks = separate
        }
        // ── Settings sheet ───────────────────────────────────────────────
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: appSettings, isPresented: $showSettings)
        }
    }

    private var nc: NotificationCenter { .default }

    private var activeCircleState: FloatingCircleState {
        sceneManager.activeScene == .browser ? circleState3 : circleState2
    }

    // MARK: - Setup

    private func setup() {
        // Sync settings into managers
        recordingManager.saveFolder          = appSettings.saveFolder
        recordingManager.separateAudioTracks = appSettings.separateAudioTracks

        // Wire sample handlers
        cameraManager.videoSampleHandler = { [weak recordingManager] buf in
            recordingManager?.appendVideoFrame(buf)
        }
        cameraManager.audioSampleHandler = { [weak recordingManager] buf in
            recordingManager?.appendMicAudio(buf)
        }
        screenCapture.audioSampleHandler = { [weak recordingManager] buf in
            recordingManager?.appendSystemAudio(buf)
        }

        // Load persisted state
        AppPersistence.load(circle: circleState2, key: "circle2")
        AppPersistence.load(circle: circleState3, key: "circle3")

        let savedScene = AppPersistence.loadScene()
        sceneManager.setScene(savedScene == .standby ? .camera : savedScene)

        if let savedURL = AppPersistence.loadBrowserURL() {
            browserURLInput = savedURL
            webNav.navigate(to: savedURL)
        }

        // Start camera (will auto-restore last camera after devices are discovered)
        cameraManager.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            restoreCamera()
        }

        // Setup floating panel
        panelController.setup(
            cameraManager:    cameraManager,
            recordingManager: recordingManager,
            sceneManager:     sceneManager,
            virtualCamera:    virtualCamera,
            circleState2:     circleState2,
            circleState3:     circleState3,
            webNav:           webNav
        )

        // Try to restore last captured window
        if savedScene == .window,
           let bundleID = AppPersistence.loadLastWindowBundleID() {
            restoreWindow(bundleID: bundleID, title: AppPersistence.loadLastWindowTitle())
        }
    }

    private func teardown() {
        if recordingManager.isRecording { recordingManager.stopRecording() }
        cameraManager.stop()
        Task { await screenCapture.stopCapture() }

        AppPersistence.save(circle: circleState2, key: "circle2")
        AppPersistence.save(circle: circleState3, key: "circle3")
    }

    private func restoreCamera() {
        guard let savedID = AppPersistence.loadCameraID() else { return }
        if let cam = cameraManager.availableCameras.first(where: { $0.uniqueID == savedID }) {
            cameraManager.selectCamera(cam)
            if AppPersistence.loadCameraMirrored() {
                cameraManager.isMirrored = true
            }
        }
    }

    private func restoreWindow(bundleID: String, title: String?) {
        Task {
            await screenCapture.refreshWindows()
            await MainActor.run {
                let match = screenCapture.availableWindows.first { w in
                    w.owningApplication?.bundleIdentifier == bundleID
                    && (title == nil || w.title == title)
                }
                if let match {
                    screenCapture.selectWindow(match)
                } else {
                    showWindowPicker = true
                }
            }
        }
    }
}
