import AVFoundation
import CoreMedia
import Combine

class RecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0

    var saveFolder: URL = FileManager.default
        .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    var separateAudioTracks: Bool = false

    private var assetWriter:    AVAssetWriter?
    private var videoInput:     AVAssetWriterInput?
    private var micInput:       AVAssetWriterInput?
    private var sysAudioInput:  AVAssetWriterInput?

    private var sessionStarted = false
    private var timer:     Timer?
    private var startTime: Date?
    private let writeQueue = DispatchQueue(label: "com.studiorecord.writer")

    // MARK: — Public append methods

    func appendVideoFrame(_ buffer: CMSampleBuffer) {
        writeQueue.async { [weak self] in
            guard let self, self.isRecording,
                  let writer = self.assetWriter,
                  let input  = self.videoInput else { return }
            if !self.sessionStarted {
                let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                writer.startSession(atSourceTime: pts)
                self.sessionStarted = true
            }
            if input.isReadyForMoreMediaData { input.append(buffer) }
        }
    }

    func appendMicAudio(_ buffer: CMSampleBuffer) {
        appendAudio(buffer, to: micInput)
    }

    func appendSystemAudio(_ buffer: CMSampleBuffer) {
        guard separateAudioTracks else { return }
        appendAudio(buffer, to: sysAudioInput)
    }

    private func appendAudio(_ buffer: CMSampleBuffer, to input: AVAssetWriterInput?) {
        writeQueue.async { [weak self] in
            guard let self, self.isRecording, self.sessionStarted, let input else { return }
            if input.isReadyForMoreMediaData { input.append(buffer) }
        }
    }

    // MARK: — Start / Stop

    func startRecording() {
        guard !isRecording else { return }

        let name = "StudioRecord_\(timestamp()).mp4"
        let url  = saveFolder.appendingPathComponent(name)

        do {
            let writer = try AVAssetWriter(url: url, fileType: .mp4)

            // Video — H.264
            let videoSettings: [String: Any] = [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  1920,
                AVVideoHeightKey: 1080,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey:  8_000_000,
                    AVVideoProfileLevelKey:    AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            let vid = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            vid.expectsMediaDataInRealTime = true
            writer.add(vid)
            videoInput = vid

            let audioSettings: [String: Any] = [
                AVFormatIDKey:         Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey:       44100.0,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey:   128_000
            ]

            // Track 1 — Microphone (always)
            let mic = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            mic.expectsMediaDataInRealTime = true
            writer.add(mic)
            micInput = mic

            // Track 2 — System audio (only when separate tracks enabled)
            if separateAudioTracks {
                let sys = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                sys.expectsMediaDataInRealTime = true
                writer.add(sys)
                sysAudioInput = sys
            } else {
                sysAudioInput = nil
            }

            writer.startWriting()
            assetWriter    = writer
            sessionStarted = false

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isRecording = true
                self.startTime   = Date()
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    guard let self, let t = self.startTime else { return }
                    self.duration = Date().timeIntervalSince(t)
                }
            }
        } catch {
            print("שגיאת אתחול הקלטה: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRecording = false
            self.timer?.invalidate()
            self.timer     = nil
            self.duration  = 0
            self.startTime = nil
        }

        writeQueue.async { [weak self] in
            guard let self, let writer = self.assetWriter else { return }
            self.videoInput?.markAsFinished()
            self.micInput?.markAsFinished()
            self.sysAudioInput?.markAsFinished()
            writer.finishWriting {
                print("נשמר: \(writer.outputURL.lastPathComponent)")
                self.assetWriter   = nil
                self.videoInput    = nil
                self.micInput      = nil
                self.sysAudioInput = nil
            }
        }
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.string(from: Date())
    }
}
