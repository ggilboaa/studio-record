import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = gravity
        view.previewLayer.backgroundColor = CGColor(gray: 0, alpha: 1)
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        guard let connection = nsView.previewLayer.connection,
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
    }
}

class PreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = previewLayer
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }

    // אל תבלע אירועי עכבר — תן ל-SwiftUI לטפל בג'סטות
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
