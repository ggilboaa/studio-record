import SwiftUI

// MARK: - Reusable card button for the floating panel

struct PanelCardButton<Content: View>: View {
    let isActive: Bool
    let activeColor: Color
    let width: CGFloat
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    init(isActive: Bool, activeColor: Color, width: CGFloat = 52,
         action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.isActive = isActive
        self.activeColor = activeColor
        self.width = width
        self.action = action
        self.content = content
    }

    var body: some View {
        Button(action: action) {
            content()
                .foregroundStyle(isActive ? activeColor : Color.appLabel2)
                .frame(width: width, height: 52)
                .background(isActive ? activeColor.opacity(0.14) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(isActive ? activeColor.opacity(0.4) : Color.black.opacity(0.09), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FloatingPanelView

struct FloatingPanelView: View {
    @ObservedObject var cameraManager:    CameraManager
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var sceneManager:     SceneManager
    @ObservedObject var virtualCamera:    VirtualCameraManager
    @ObservedObject var circleState2:     FloatingCircleState
    @ObservedObject var circleState3:     FloatingCircleState
    @ObservedObject var webNav:           WebNavState

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().opacity(0.4)
            buttonsRow
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
        .padding(14)
        .fixedSize()
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Title bar (drag handle)

    private var titleBar: some View {
        HStack {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle().fill(Color.black.opacity(0.18)).frame(width: 3, height: 3)
                }
            }
            Spacer()
            Text("פאנל שליטה")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.appLabel4)
            Spacer()
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.05))
                    .frame(width: 15, height: 15)
                    .overlay(Text("–").font(.system(size: 11)).foregroundStyle(Color.appLabel4))
                RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.05))
                    .frame(width: 15, height: 15)
                    .overlay(Text("×").font(.system(size: 10)).foregroundStyle(Color.appLabel4))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.03))
    }

    // MARK: - Buttons row

    private var buttonsRow: some View {
        HStack(spacing: 8) {
            // שידור
            PanelCardButton(isActive: virtualCamera.isStreaming, activeColor: .appBlue, width: 56,
                            action: { virtualCamera.toggle() }) {
                VStack(spacing: 3) {
                    broadcastIcon(color: virtualCamera.isStreaming ? Color.appBlueText : Color.appLabel2)
                    Text("שידור").font(.system(size: 10.5, weight: .bold))
                }
            }

            // הקלטה / טיימר
            PanelCardButton(isActive: recordingManager.isRecording, activeColor: .appRed,
                            width: recordingManager.isRecording ? 66 : 52,
                            action: {
                                if recordingManager.isRecording { recordingManager.stopRecording() }
                                else { recordingManager.startRecording() }
                            }) {
                VStack(spacing: 3) {
                    if recordingManager.isRecording {
                        Circle().fill(Color.appRed).frame(width: 12, height: 12)
                        Text(formatDuration(recordingManager.duration))
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .environment(\.layoutDirection, .leftToRight)
                    } else {
                        Image(systemName: "record.circle").font(.system(size: 14, weight: .medium))
                        Text("הקלטה").font(.system(size: 10.5, weight: .bold))
                    }
                }
            }

            // המתנה
            PanelCardButton(isActive: sceneManager.activeScene == .standby, activeColor: .orange, width: 52,
                            action: { sceneManager.toggleStandby() }) {
                VStack(spacing: 3) {
                    HStack(spacing: 2.5) {
                        RoundedRectangle(cornerRadius: 2).frame(width: 3, height: 12)
                        RoundedRectangle(cornerRadius: 2).frame(width: 3, height: 12)
                    }
                    Text("המתנה").font(.system(size: 10.5, weight: .bold))
                }
            }

            // סצנות 1 / 2 / 3
            sceneSwitcher

            // אודיו (מיקרופון)
            PanelCardButton(isActive: cameraManager.isMicMuted, activeColor: .appRed, width: 52,
                            action: { cameraManager.toggleMic() }) {
                VStack(spacing: 3) {
                    Image(systemName: cameraManager.isMicMuted ? "mic.slash.fill" : "mic")
                        .font(.system(size: 14, weight: .medium))
                    Text("אודיו").font(.system(size: 10.5, weight: .bold))
                }
            }

            // הסתר וידאו
            PanelCardButton(isActive: isCurrentlyHidden, activeColor: .appRed, width: 52,
                            action: { toggleVisibility() }) {
                VStack(spacing: 3) {
                    Circle().stroke(lineWidth: 1.6).frame(width: 13, height: 13)
                    Text("וידאו").font(.system(size: 10.5, weight: .bold))
                }
            }

            // שקפים (סצנה 3 בלבד)
            if sceneManager.activeScene == .browser {
                Rectangle().fill(Color.black.opacity(0.08)).frame(width: 1, height: 38)
                slideButton(text: "‹", action: { webNav.prevSlide() })
                slideButton(text: "›", action: { webNav.nextSlide() })
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Sub-views

    private var sceneSwitcher: some View {
        HStack(spacing: 2) {
            ForEach([AppScene.camera, .window, .browser], id: \.rawValue) { scene in
                let active = sceneManager.activeScene == scene
                Button { sceneManager.setScene(scene) } label: {
                    Text(sceneNumber(scene))
                        .font(.system(size: 15, weight: active ? .heavy : .bold))
                        .foregroundStyle(active ? Color.appBlueText : Color.appLabel3)
                        .frame(width: 34, height: 44)
                        .background(
                            Group {
                                if active {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.white)
                                        .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.appSegment)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func slideButton(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.appLabel2)
                .frame(width: 38, height: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.black.opacity(0.09), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func broadcastIcon(color: Color) -> some View {
        ZStack {
            Circle().fill(color).frame(width: 5, height: 5)
            Circle().stroke(color.opacity(0.55), lineWidth: 1.4).frame(width: 11, height: 11)
            Circle().stroke(color.opacity(0.28), lineWidth: 1.4).frame(width: 16, height: 16)
        }
        .frame(width: 16, height: 16)
    }

    // MARK: - Helpers

    private func sceneNumber(_ scene: AppScene) -> String {
        switch scene {
        case .camera:  return "1"
        case .window:  return "2"
        case .browser: return "3"
        case .standby: return "4"
        }
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
