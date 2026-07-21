import SwiftUI

struct Scene1View: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session, isMirrored: cameraManager.isMirrored)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            if cameraManager.isCameraOff {
                Color.black
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        Image(systemName: "video.slash")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}
