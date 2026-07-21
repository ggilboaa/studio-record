import SwiftUI
import AVFoundation

// Unified clip shape — circle or rounded rect based on FloatingCircleState.shape
struct CircleClipShape: Shape {
    let shape: CircleShape
    let cornerFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle:
            return Path(ellipseIn: rect)
        case .roundedRect:
            let r = min(rect.width, rect.height) * cornerFraction
            return Path(roundedRect: rect, cornerRadius: r)
        }
    }
}

// Scene 2: window capture only — circle is rendered as overlay in ContentView
struct Scene2View: View {
    @ObservedObject var screenCapture: ScreenCaptureManager
    @Binding var showPicker: Bool

    var body: some View {
        ZStack {
            if screenCapture.isCapturing {
                WindowCaptureView(layer: screenCapture.displayLayer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.black.frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 16) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary)
                    Text("בחר חלון לשיתוף")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Button("בחר חלון") { showPicker = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            WindowPickerView(screenCapture: screenCapture, isPresented: $showPicker)
        }
    }
}

// MARK: — Window capture display

struct WindowCaptureView: NSViewRepresentable {
    let layer: AVSampleBufferDisplayLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = layer
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = CGColor(gray: 0, alpha: 1)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        layer.frame = nsView.bounds
    }
}

// MARK: — Floating camera circle (used from ContentView overlay)

struct FloatingCameraCircle: View {
    let session: AVCaptureSession
    let isMirrored: Bool
    @ObservedObject var state: FloatingCircleState

    @State private var dragOffset: CGSize = .zero
    @State private var lastSize: CGFloat  = 150

    var body: some View {
        ZStack {
            CameraPreviewView(session: session, isMirrored: isMirrored, gravity: .resizeAspectFill)
                .frame(width: state.frameWidth, height: state.frameHeight)
                .clipShape(CircleClipShape(shape: state.shape, cornerFraction: 0.12))
                .overlay(CircleClipShape(shape: state.shape, cornerFraction: 0.12)
                    .stroke(Color.white.opacity(0.35), lineWidth: 2))
                .shadow(color: .black.opacity(0.45), radius: 10)
                .allowsHitTesting(false)

            // Transparent drag target so gestures register over the camera layer
            CircleClipShape(shape: state.shape, cornerFraction: 0.12)
                .fill(Color(white: 0, opacity: 0.001))
                .frame(width: state.frameWidth, height: state.frameHeight)

            // Resize handle — bottom-right edge
            if !state.isLocked {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .offset(
                        x: state.frameWidth  / 2 - 12,
                        y: state.frameHeight / 2 - 12
                    )
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { v in
                                let d = (v.translation.width + v.translation.height) / 2
                                state.size = max(80, min(420, lastSize + d))
                            }
                            .onEnded { _ in lastSize = state.size }
                    )
            }
        }
        .position(
            x: state.position.x + dragOffset.width,
            y: state.position.y + dragOffset.height
        )
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { v in
                    guard !state.isLocked else { return }
                    dragOffset = v.translation
                }
                .onEnded { v in
                    guard !state.isLocked else { return }
                    state.position.x += v.translation.width
                    state.position.y += v.translation.height
                    dragOffset = .zero
                }
        )
        .gesture(MagnifyGesture()
            .onChanged { v in
                guard !state.isLocked else { return }
                state.size = max(80, min(420, lastSize * v.magnification))
            }
            .onEnded { _ in
                guard !state.isLocked else { return }
                lastSize = state.size
            }
        )
        .onAppear { lastSize = state.size }
    }
}
