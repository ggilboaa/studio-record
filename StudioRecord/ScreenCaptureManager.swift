import ScreenCaptureKit
import AVFoundation
import AppKit

class ScreenCaptureManager: NSObject, ObservableObject {
    @Published var availableWindows:    [SCWindow] = []
    @Published var selectedWindow:      SCWindow?
    @Published var isCapturing          = false
    @Published var permissionDenied     = false
    @Published var isSystemAudioMuted   = false

    let displayLayer = AVSampleBufferDisplayLayer()
    var audioSampleHandler: ((CMSampleBuffer) -> Void)?
    var videoSampleHandler: ((CMSampleBuffer) -> Void)?

    private var stream: SCStream?
    private let videoQueue = DispatchQueue(label: "com.studiorecord.sc.video")
    private let audioQueue = DispatchQueue(label: "com.studiorecord.sc.audio")

    func refreshWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let windows = content.windows.filter { w in
                w.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                    && w.frame.width > 100
            }.sorted {
                ($0.owningApplication?.applicationName ?? "") < ($1.owningApplication?.applicationName ?? "")
            }
            await MainActor.run { self.availableWindows = windows }
        } catch {
            await MainActor.run { self.permissionDenied = true }
        }
    }

    func selectWindow(_ window: SCWindow) {
        Task { await startCapture(window: window) }
    }

    private func startCapture(window: SCWindow) async {
        await stopCapture()

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = 1920
        config.height = 1080
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.capturesAudio = true
        config.sampleRate    = 44100
        config.channelCount  = 2

        do {
            let s = SCStream(filter: filter, configuration: config, delegate: self)
            try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
            try s.addStreamOutput(self, type: .audio,  sampleHandlerQueue: audioQueue)
            try await s.startCapture()
            stream = s
            await MainActor.run {
                self.selectedWindow = window
                self.isCapturing    = true
            }
        } catch {
            print("SCStream שגיאה: \(error)")
        }
    }

    func stopCapture() async {
        guard let s = stream else { return }
        stream = nil
        try? await s.stopCapture()
        await MainActor.run { self.isCapturing = false }
    }
}

extension ScreenCaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        switch type {
        case .screen:
            videoSampleHandler?(sampleBuffer)
            let buf = sampleBuffer
            DispatchQueue.main.async { [weak self] in
                self?.displayLayer.enqueue(buf)
            }
        case .audio:
            if !isSystemAudioMuted { audioSampleHandler?(sampleBuffer) }
        case .microphone:
            break
        @unknown default:
            break
        }
    }
}

extension ScreenCaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in self?.isCapturing = false }
    }
}
