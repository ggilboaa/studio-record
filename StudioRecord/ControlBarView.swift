import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ControlBarView: View {
    @ObservedObject var cameraManager:    CameraManager
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var sceneManager:     SceneManager
    @ObservedObject var circleState:      FloatingCircleState
    @ObservedObject var webNav:           WebNavState
    @ObservedObject var standbyState:     StandbyState
    @ObservedObject var virtualCamera:    VirtualCameraManager
    @ObservedObject var screenCapture:    ScreenCaptureManager
    @Binding var showWindowPicker:  Bool
    @Binding var browserURLInput:   String
    @Binding var showSettings:      Bool

    @State private var showStandbyImagePicker = false

    var body: some View {
        HStack(spacing: 12) {

            // ── Scene switcher ──────────────────────────────────────────
            HStack(spacing: 2) {
                ForEach(AppScene.allCases, id: \.rawValue) { scene in
                    let active = sceneManager.activeScene == scene
                    Button { sceneManager.setScene(scene) } label: {
                        Label(scene.title, systemImage: scene.icon)
                            .labelStyle(.iconOnly)
                            .foregroundStyle(active ? Color.appBlueText : Color.appLabel3)
                            .frame(minWidth: 30, minHeight: 26)
                            .background(
                                Group {
                                    if active {
                                        RoundedRectangle(cornerRadius: 6).fill(Color.white)
                                            .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .help(scene.title)
                }
            }
            .padding(3)
            .background(Color.appSegment)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            Divider().frame(height: 22)

            // ── Camera picker + Flip (scenes 1, 2, 3 — not standby) ─────
            if sceneManager.activeScene != .standby {
                Picker(selection: Binding(
                    get: { cameraManager.selectedCamera },
                    set: { cam in if let cam { cameraManager.selectCamera(cam) } }
                ), label: EmptyView()) {
                    Text("בחר מצלמה").tag(Optional<AVCaptureDevice>(nil))
                    ForEach(cameraManager.availableCameras, id: \.uniqueID) { cam in
                        Text(cam.localizedName).tag(Optional(cam))
                    }
                }
                .frame(maxWidth: 200)

                Button { cameraManager.toggleFlip() } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                .buttonStyle(.bordered)
                .tint(cameraManager.isMirrored ? .accentColor : nil)
                .help("היפוך")
            }

            // ── URL bar + slide controls (scene 3) ──────────────────────
            if sceneManager.activeScene == .browser {
                Button { webNav.goBack() } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless).disabled(!webNav.canGoBack)
                Button { webNav.goForward() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless).disabled(!webNav.canGoForward)
                Button { webNav.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)

                TextField("הדבק קישור ולחץ Enter", text: $browserURLInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { webNav.navigate(to: browserURLInput) }

                Button("טען") { webNav.navigate(to: browserURLInput) }
                    .buttonStyle(.bordered)

                Divider().frame(height: 22)

                Button { webNav.prevSlide() } label: { Image(systemName: "chevron.right.2") }
                    .buttonStyle(.bordered).help("שקף קודם")
                Button { webNav.nextSlide() } label: { Image(systemName: "chevron.left.2") }
                    .buttonStyle(.bordered).help("שקף הבא")
            }

            // ── Change window (scene 2) ──────────────────────────────────
            if sceneManager.activeScene == .window {
                Button { showWindowPicker = true } label: {
                    Label("שנה חלון", systemImage: "rectangle.2.swap")
                }
                .buttonStyle(.bordered)
            }

            // ── Standby controls (scene 4) ──────────────────────────────
            if sceneManager.activeScene == .standby {
                Button { showStandbyImagePicker = true } label: {
                    Label("תמונה", systemImage: "photo")
                }
                .buttonStyle(.bordered)

                if standbyState.image != nil {
                    Button { standbyState.clearImage() } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("הסר תמונה")
                }

                Divider().frame(height: 22)

                // Free-text field + preset quick-pick
                TextField("טקסט על המסך...", text: $standbyState.message)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .environment(\.layoutDirection, .rightToLeft)

                Menu {
                    ForEach(StandbyState.messages, id: \.self) { msg in
                        Button(msg) { standbyState.message = msg }
                    }
                    Divider()
                    Button("נקה טקסט") { standbyState.message = "" }
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                .buttonStyle(.bordered)
                .help("הודעות מוכנות")
            }

            // ── Circle lock + shape (scenes 2 & 3) ──────────────────────
            if sceneManager.activeScene.hasFloatingCircle {
                Divider().frame(height: 22)

                Button { circleState.isLocked.toggle() } label: {
                    Image(systemName: circleState.isLocked ? "lock.fill" : "lock.open")
                }
                .buttonStyle(.bordered)
                .tint(circleState.isLocked ? .orange : nil)
                .help(circleState.isLocked ? "בטל נעילה" : "נעל מיקום")

                Button {
                    circleState.shape = circleState.shape == .circle ? .roundedRect : .circle
                } label: {
                    Image(systemName: circleState.shape == .circle
                          ? "circle.dotted" : "rectangle.roundedtop")
                }
                .buttonStyle(.bordered)
                .help(circleState.shape == .circle ? "שנה למלבן מעוגל" : "שנה לעיגול")
            }

            Spacer()

            // ── Settings ─────────────────────────────────────────────────
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(.bordered).help("הגדרות")

            Divider().frame(height: 22)

            // ── Hide video (unified — camera in scene1, circle in 2&3) ──
            Button {
                if sceneManager.activeScene == .camera {
                    cameraManager.toggleCamera()
                } else if sceneManager.activeScene.hasFloatingCircle {
                    circleState.isHidden.toggle()
                }
            } label: {
                Image(systemName: isVideoHidden ? "eye.slash.fill" : "eye")
            }
            .buttonStyle(.bordered)
            .tint(isVideoHidden ? .red : nil)
            .disabled(sceneManager.activeScene == .standby)
            .help(isVideoHidden ? "הצג מצלמה" : "הסתר מצלמה")

            // ── System audio mute ────────────────────────────────────────
            Button { screenCapture.isSystemAudioMuted.toggle() } label: {
                Image(systemName: screenCapture.isSystemAudioMuted
                      ? "speaker.slash.fill" : "speaker.wave.2")
            }
            .buttonStyle(.bordered)
            .tint(screenCapture.isSystemAudioMuted ? .red : nil)
            .help(screenCapture.isSystemAudioMuted ? "בטל השתקת מערכת" : "השתק אודיו מערכת")

            // ── Mic mute ─────────────────────────────────────────────────
            Button { cameraManager.toggleMic() } label: {
                Image(systemName: cameraManager.isMicMuted ? "mic.slash.fill" : "mic")
            }
            .buttonStyle(.bordered)
            .tint(cameraManager.isMicMuted ? .red : nil)
            .help(cameraManager.isMicMuted ? "בטל השתקה" : "השתק מיקרופון")

            // ── Recording timer ──────────────────────────────────────────
            if recordingManager.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text(formatDuration(recordingManager.duration))
                        .monospacedDigit()
                        .foregroundStyle(.red)
                        .fontWeight(.medium)
                }
            }

            // ── Record / Stop ────────────────────────────────────────────
            Button {
                if recordingManager.isRecording { recordingManager.stopRecording() }
                else { recordingManager.startRecording() }
            } label: {
                Label(
                    recordingManager.isRecording ? "עצור" : "הקלטה",
                    systemImage: recordingManager.isRecording
                        ? "stop.circle.fill" : "record.circle"
                )
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(recordingManager.isRecording ? .red : .accentColor)

            Divider().frame(height: 22)

            // ── Broadcast ────────────────────────────────────────────────
            Button { virtualCamera.toggle() } label: {
                Label(
                    virtualCamera.isStreaming ? "משדר" : "שידור",
                    systemImage: virtualCamera.isStreaming
                        ? "dot.radiowaves.left.and.right"
                        : "antenna.radiowaves.left.and.right"
                )
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(virtualCamera.isStreaming ? .green : nil)
            .help(virtualCamera.isStreaming ? "כבה שידור" : "הפעל שידור")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .environment(\.layoutDirection, .rightToLeft)
        .fileImporter(
            isPresented: $showStandbyImagePicker,
            allowedContentTypes: [.image]
        ) { result in
            if case .success(let url) = result {
                standbyState.setImage(from: url)
            }
        }
    }

    // MARK: - Helpers

    private var isVideoHidden: Bool {
        switch sceneManager.activeScene {
        case .camera:  return cameraManager.isCameraOff
        case .window, .browser: return circleState.isHidden
        case .standby: return false
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
