import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Card Button Style (used in left section and right section)

private struct ControlCardButton<Content: View>: View {
    let isActive: Bool
    let activeColor: Color
    let activeBorderColor: Color
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .foregroundStyle(isActive ? activeColor : Color.appLabel2)
                .frame(minWidth: 60, maxWidth: 60, minHeight: 54, maxHeight: 54)
                .background(isActive ? activeColor.opacity(0.12) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(
                            isActive ? activeBorderColor : Color.black.opacity(0.09),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Broadcast Icon (nested circles, same as floating panel)

private struct BroadcastIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Circle().stroke(color.opacity(0.55), lineWidth: 1.4).frame(width: 12, height: 12)
            Circle().stroke(color.opacity(0.28), lineWidth: 1.4).frame(width: 18, height: 18)
        }
        .frame(width: 18, height: 18)
    }
}

// MARK: - Recording Icon

private struct RecordingIcon: View {
    let isRecording: Bool

    var body: some View {
        if isRecording {
            Circle()
                .fill(Color.appRed)
                .frame(width: 13, height: 13)
                .shadow(color: Color.appRed.opacity(0.55), radius: 4, x: 0, y: 0)
        } else {
            Image(systemName: "record.circle")
                .font(.system(size: 14, weight: .medium))
        }
    }
}

// MARK: - Standby Icon (two vertical bars)

private struct StandbyIcon: View {
    var body: some View {
        HStack(spacing: 2.5) {
            RoundedRectangle(cornerRadius: 2).frame(width: 3, height: 13)
            RoundedRectangle(cornerRadius: 2).frame(width: 3, height: 13)
        }
    }
}

// MARK: - ControlBarView

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
        VStack(spacing: 0) {
            mainRow
            if hasSecondaryRow {
                Divider().opacity(0.5)
                secondaryRow
            }
        }
        .background(Color(red: 245/255, green: 245/255, blue: 247/255))
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

    // MARK: - Main Row

    private var mainRow: some View {
        HStack(spacing: 0) {
            // ── LEFT: שידור · הקלטה · המתנה ─────────────────────────────
            HStack(spacing: 8) {
                // שידור
                ControlCardButton(
                    isActive: virtualCamera.isStreaming,
                    activeColor: Color(red: 0, green: 100/255, blue: 216/255),
                    activeBorderColor: Color(red: 0, green: 122/255, blue: 255/255).opacity(0.42),
                    action: { virtualCamera.toggle() }
                ) {
                    VStack(spacing: 3) {
                        BroadcastIcon(color: virtualCamera.isStreaming
                            ? Color(red: 0, green: 100/255, blue: 216/255)
                            : Color.appLabel2)
                        Text("שידור")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                }

                // הקלטה
                ControlCardButton(
                    isActive: recordingManager.isRecording,
                    activeColor: Color(red: 216/255, green: 48/255, blue: 42/255),
                    activeBorderColor: Color(red: 255/255, green: 59/255, blue: 48/255).opacity(0.44),
                    action: {
                        if recordingManager.isRecording { recordingManager.stopRecording() }
                        else { recordingManager.startRecording() }
                    }
                ) {
                    VStack(spacing: 3) {
                        RecordingIcon(isRecording: recordingManager.isRecording)
                        if recordingManager.isRecording {
                            Text(formatDuration(recordingManager.duration))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .environment(\.layoutDirection, .leftToRight)
                        } else {
                            Text("הקלטה")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                    }
                }

                // המתנה
                ControlCardButton(
                    isActive: sceneManager.activeScene == .standby,
                    activeColor: .orange,
                    activeBorderColor: Color.orange.opacity(0.44),
                    action: { sceneManager.toggleStandby() }
                ) {
                    VStack(spacing: 3) {
                        StandbyIcon()
                        Text("המתנה")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                }
            }

            Spacer()

            // ── CENTER: Scene switcher ────────────────────────────────────
            HStack(spacing: 0) {
                ForEach([AppScene.camera, .window, .browser], id: \.rawValue) { scene in
                    let active = sceneManager.activeScene == scene
                    Button {
                        sceneManager.setScene(scene)
                    } label: {
                        VStack(spacing: 1) {
                            Text("סצנה \(sceneNumber(scene))")
                                .font(.system(size: 9.5, weight: .semibold))
                                .opacity(0.72)
                            Text(scene.title)
                                .font(.system(size: 12.5, weight: active ? .bold : .semibold))
                        }
                        .foregroundStyle(active ? Color.appBlueText : Color.appLabel3)
                        .frame(minWidth: 98, minHeight: 48)
                        .background(
                            Group {
                                if active {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.white)
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
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            // ── RIGHT: mic mute · hide video · settings ───────────────────
            HStack(spacing: 8) {
                // השתק אודיו
                ControlCardButton(
                    isActive: cameraManager.isMicMuted,
                    activeColor: Color.appRed,
                    activeBorderColor: Color.appRed.opacity(0.44),
                    action: { cameraManager.toggleMic() }
                ) {
                    VStack(spacing: 3) {
                        Image(systemName: cameraManager.isMicMuted ? "mic.slash.fill" : "mic")
                            .font(.system(size: 14, weight: .medium))
                        Text("השתק")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                }

                // הסתר וידאו
                ControlCardButton(
                    isActive: isVideoHidden,
                    activeColor: Color.appRed,
                    activeBorderColor: Color.appRed.opacity(0.44),
                    action: { toggleVideo() }
                ) {
                    VStack(spacing: 3) {
                        Circle()
                            .stroke(lineWidth: 1.6)
                            .frame(width: 13, height: 13)
                        Text("וידאו")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                }
                .disabled(sceneManager.activeScene == .standby)

                // Settings gear — plain borderless, no card style
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appLabel2)
                }
                .buttonStyle(.plain)
                .help("הגדרות")
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
    }

    // MARK: - Secondary Row

    private var hasSecondaryRow: Bool {
        true // Always show secondary row (content varies by scene)
    }

    @ViewBuilder
    private var secondaryRow: some View {
        if sceneManager.activeScene == .browser {
            // Browser: nav row + separate centered circle controls row
            VStack(spacing: 0) {
                secondaryRowContainer { browserNavRow }
                Divider().opacity(0.5)
                HStack(spacing: 8) {
                    Spacer()
                    circleControlsButtons
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(Color.white)
                .environment(\.layoutDirection, .rightToLeft)
            }
        } else {
            secondaryRowContainer {
                switch sceneManager.activeScene {
                case .camera:  cameraSecondaryRow
                case .window:  windowSecondaryRow
                case .standby: standbySecondaryRow
                default:       EmptyView()
                }
            }
        }
    }

    private func secondaryRowContainer<C: View>(@ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 8) { content() }
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(Color.white)
            .environment(\.layoutDirection, .rightToLeft)
    }

    // Scene 1: Camera picker + flip
    private var cameraSecondaryRow: some View {
        Group {
            Picker(selection: Binding(
                get: { cameraManager.selectedCamera },
                set: { cam in if let cam { cameraManager.selectCamera(cam) } }
            ), label: EmptyView()) {
                Text("בחר מצלמה").tag(Optional<AVCaptureDevice>(nil))
                ForEach(cameraManager.availableCameras, id: \.uniqueID) { cam in
                    Text(cam.localizedName).tag(Optional(cam))
                }
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 20)

            Button { cameraManager.toggleFlip() } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .buttonStyle(.bordered)
            .tint(cameraManager.isMirrored ? .accentColor : nil)
            .help("היפוך")
        }
    }

    // Scene 2: Change window + lock + shape + flip
    private var windowSecondaryRow: some View {
        Group {
            Button { showWindowPicker = true } label: {
                Label("שנה חלון", systemImage: "rectangle.2.swap")
            }
            .buttonStyle(.bordered)

            Divider().frame(height: 20)

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

            Button { cameraManager.toggleFlip() } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .buttonStyle(.bordered)
            .tint(cameraManager.isMirrored ? .accentColor : nil)
            .help("הפוך צדדים")
        }
    }

    // Scene 3: Browser nav + URL + slides (circle controls are in a separate row)
    private var browserNavRow: some View {
        Group {
            Button { webNav.goBack() } label: {
                Text("‹").font(.system(size: 15, weight: .medium)).frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.12), lineWidth: 1))
            .disabled(!webNav.canGoBack)

            Button { webNav.goForward() } label: {
                Text("›").font(.system(size: 15, weight: .medium)).frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.12), lineWidth: 1))
            .disabled(!webNav.canGoForward)

            Button { webNav.reload() } label: {
                Image(systemName: "arrow.clockwise").frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.12), lineWidth: 1))

            TextField("הדבק קישור ולחץ Enter", text: $browserURLInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 236/255, green: 236/255, blue: 239/255))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity)
                .onSubmit { webNav.navigate(to: browserURLInput) }

            Button("טען") { webNav.navigate(to: browserURLInput) }
                .buttonStyle(.bordered)

            Divider().frame(height: 20)

            Button { webNav.prevSlide() } label: { Image(systemName: "chevron.right.2") }
                .buttonStyle(.bordered).help("שקף קודם")
            Button { webNav.nextSlide() } label: { Image(systemName: "chevron.left.2") }
                .buttonStyle(.bordered).help("שקף הבא")
        }
    }

    // Shared circle controls (lock + shape + flip) — used centered in browser's second row
    @ViewBuilder
    private var circleControlsButtons: some View {
        Button { circleState.isLocked.toggle() } label: {
            Image(systemName: circleState.isLocked ? "lock.fill" : "lock.open")
        }
        .buttonStyle(.bordered)
        .tint(circleState.isLocked ? .orange : nil)
        .help(circleState.isLocked ? "בטל נעילה" : "נעל מיקום")

        Button {
            circleState.shape = circleState.shape == .circle ? .roundedRect : .circle
        } label: {
            Image(systemName: circleState.shape == .circle ? "circle.dotted" : "rectangle.roundedtop")
        }
        .buttonStyle(.bordered)
        .help(circleState.shape == .circle ? "שנה למלבן מעוגל" : "שנה לעיגול")

        Button { cameraManager.toggleFlip() } label: {
            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
        }
        .buttonStyle(.bordered)
        .tint(cameraManager.isMirrored ? .accentColor : nil)
        .help("הפוך צדדים")
    }

    // Scene 4: Standby image + message + presets
    private var standbySecondaryRow: some View {
        Group {
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

            TextField("טקסט על המסך...", text: $standbyState.message)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 236/255, green: 236/255, blue: 239/255))
                .clipShape(RoundedRectangle(cornerRadius: 180))
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: 180)

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
    }

    // MARK: - Helpers

    private var isVideoHidden: Bool {
        switch sceneManager.activeScene {
        case .camera:  return cameraManager.isCameraOff
        case .window, .browser: return circleState.isHidden
        case .standby: return false
        }
    }

    private func toggleVideo() {
        switch sceneManager.activeScene {
        case .camera:
            cameraManager.toggleCamera()
        case .window, .browser:
            circleState.isHidden.toggle()
        case .standby:
            break
        }
    }

    private func sceneNumber(_ scene: AppScene) -> String {
        switch scene {
        case .camera:  return "1"
        case .window:  return "2"
        case .browser: return "3"
        case .standby: return "4"
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
