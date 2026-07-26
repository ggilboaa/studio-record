import AVFoundation
import Combine

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCamera: AVCaptureDevice?
    @Published var isMirrored: Bool = false
    @Published var isMicMuted: Bool = false
    @Published var isCameraOff: Bool = false

    private var videoInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.studiorecord.session")

    // Outputs for recording pipeline
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let videoQueue = DispatchQueue(label: "com.studiorecord.videodata")
    private let audioQueue = DispatchQueue(label: "com.studiorecord.audiodata")

    var videoSampleHandler: ((CMSampleBuffer) -> Void)?
    var audioSampleHandler: ((CMSampleBuffer) -> Void)?

    func start() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices

        // Request mic permission first, then configure session
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            guard let self else { return }
            self.sessionQueue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1920x1080
                self.addMicInput()
                self.addDataOutputs()
                self.session.commitConfiguration()
            }
        }

        if let camera = availableCameras.first {
            selectCamera(camera)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func selectCamera(_ device: AVCaptureDevice) {
        DispatchQueue.main.async { self.selectedCamera = device }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if let old = self.videoInput { self.session.removeInput(old) }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoInput = input
                }
            } catch {
                print("שגיאת מצלמה: \(error)")
            }
            self.session.commitConfiguration()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func toggleFlip() { isMirrored.toggle() }
    func toggleMic() { isMicMuted.toggle() }
    func toggleCamera() { isCameraOff.toggle() }

    private func addMicInput() {
        guard let mic = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: mic),
              session.canAddInput(input) else { return }
        session.addInput(input)
    }

    private func addDataOutputs() {
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        audioDataOutput.setSampleBufferDelegate(self, queue: audioQueue)
        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === videoDataOutput {
            videoSampleHandler?(sampleBuffer)
        } else if output === audioDataOutput, !isMicMuted {
            audioSampleHandler?(sampleBuffer)
        }
    }
}
