import SwiftUI

struct FloatingPanelView: View {
    @ObservedObject var cameraManager:    CameraManager
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var sceneManager:     SceneManager
    @ObservedObject var virtualCamera:    VirtualCameraManager
    @ObservedObject var circleState2:     FloatingCircleState
    @ObservedObject var circleState3:     FloatingCircleState
    @ObservedObject var webNav:           WebNavState

    var body: some View {
        HStack(spacing: 6) {

            // ── שידור ──────────────────────────────────────────────────
            Button { virtualCamera.toggle() } label: {
                Image(systemName: virtualCamera.isStreaming
                      ? "dot.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right")
            }
            .buttonStyle(.bordered)
            .tint(virtualCamera.isStreaming ? .green : nil)
            .help(virtualCamera.isStreaming ? "כבה שידור" : "הפעל שידור")

            Divider().frame(height: 20)

            // ── הקלטה + טיימר ──────────────────────────────────────────
            if recordingManager.isRecording {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                    Text(formatDuration(recordingManager.duration))
                        .monospacedDigit()
                        .foregroundStyle(.red)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            Button {
                if recordingManager.isRecording { recordingManager.stopRecording() }
                else { recordingManager.startRecording() }
            } label: {
                Image(systemName: recordingManager.isRecording ? "stop.circle.fill" : "record.circle")
            }
            .buttonStyle(.bordered)
            .tint(recordingManager.isRecording ? .red : nil)
            .help(recordingManager.isRecording ? "עצור הקלטה" : "התחל הקלטה")

            Divider().frame(height: 20)

            // ── המתנה ───────────────────────────────────────────────────
            Button { sceneManager.toggleStandby() } label: {
                Image(systemName: "pause.rectangle")
            }
            .buttonStyle(.bordered)
            .tint(sceneManager.activeScene == .standby ? .orange : nil)
            .help("מצב המתנה")

            Divider().frame(height: 20)

            // ── סצנות 1/2/3 ─────────────────────────────────────────────
            HStack(spacing: 3) {
                ForEach([AppScene.camera, .window, .browser], id: \.rawValue) { scene in
                    Button { sceneManager.setScene(scene) } label: {
                        Image(systemName: scene.icon)
                    }
                    .buttonStyle(.bordered)
                    .tint(sceneManager.activeScene == scene ? .accentColor : nil)
                    .help(scene.title)
                }
            }

            Divider().frame(height: 20)

            // ── מיקרופון + הסתרה ─────────────────────────────────────────
            Button { cameraManager.toggleMic() } label: {
                Image(systemName: cameraManager.isMicMuted ? "mic.slash.fill" : "mic")
            }
            .buttonStyle(.bordered)
            .tint(cameraManager.isMicMuted ? .red : nil)
            .help(cameraManager.isMicMuted ? "בטל השתקה" : "השתק מיקרופון")

            Button { toggleVisibility() } label: {
                Image(systemName: isCurrentlyHidden ? "eye.slash.fill" : "eye")
            }
            .buttonStyle(.bordered)
            .help(isCurrentlyHidden ? "הצג" : "הסתר")

            // ── שקפים (סצנה 3 בלבד) ─────────────────────────────────────
            if sceneManager.activeScene == .browser {
                Divider().frame(height: 20)
                Button { webNav.prevSlide() } label: {
                    Image(systemName: "chevron.right.2")
                }
                .buttonStyle(.bordered)
                .help("שקף קודם")

                Button { webNav.nextSlide() } label: {
                    Image(systemName: "chevron.left.2")
                }
                .buttonStyle(.bordered)
                .help("שקף הבא")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.colorScheme, .dark)
    }

    private var activeCircleState: FloatingCircleState {
        sceneManager.activeScene == .browser ? circleState3 : circleState2
    }

    private var isCurrentlyHidden: Bool {
        sceneManager.activeScene == .camera
            ? cameraManager.isCameraOff
            : activeCircleState.isHidden
    }

    private func toggleVisibility() {
        if sceneManager.activeScene == .camera {
            cameraManager.toggleCamera()
        } else {
            activeCircleState.isHidden.toggle()
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
