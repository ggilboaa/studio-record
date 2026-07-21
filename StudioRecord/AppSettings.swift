import Foundation
import AppKit

enum WindowFillMode: String, CaseIterable {
    case fit  = "fit"
    case fill = "fill"

    var title: String {
        switch self {
        case .fit:  return "התאם (Fit)"
        case .fill: return "מלא (Fill)"
        }
    }
}

enum RecordingResolution: String, CaseIterable {
    case hd720  = "720p"
    case hd1080 = "1080p"
    case uhd4k  = "4K"

    var title: String { rawValue }
    var size: (width: Int, height: Int) {
        switch self {
        case .hd720:  return (1280, 720)
        case .hd1080: return (1920, 1080)
        case .uhd4k:  return (3840, 2160)
        }
    }
}

class AppSettings: ObservableObject {
    private let ud = UserDefaults.standard
    private enum Keys {
        static let saveFolder           = "saveFolder"
        static let separateAudioTracks  = "separateAudioTracks"
        static let windowFillMode       = "windowFillMode"
        static let recordingResolution  = "recordingResolution"
    }

    @Published var saveFolder: URL {
        didSet { ud.set(saveFolder.path, forKey: Keys.saveFolder) }
    }
    @Published var separateAudioTracks: Bool {
        didSet { ud.set(separateAudioTracks, forKey: Keys.separateAudioTracks) }
    }
    @Published var windowFillMode: WindowFillMode {
        didSet { ud.set(windowFillMode.rawValue, forKey: Keys.windowFillMode) }
    }
    @Published var recordingResolution: RecordingResolution {
        didSet { ud.set(recordingResolution.rawValue, forKey: Keys.recordingResolution) }
    }

    init() {
        let defaultFolder = FileManager.default
            .urls(for: .downloadsDirectory, in: .userDomainMask)[0]

        if let path = UserDefaults.standard.string(forKey: Keys.saveFolder),
           FileManager.default.fileExists(atPath: path) {
            saveFolder = URL(fileURLWithPath: path)
        } else {
            saveFolder = defaultFolder
        }
        separateAudioTracks = UserDefaults.standard.bool(forKey: Keys.separateAudioTracks)
        windowFillMode      = WindowFillMode(rawValue: UserDefaults.standard.string(forKey: Keys.windowFillMode) ?? "") ?? .fit
        recordingResolution = RecordingResolution(rawValue: UserDefaults.standard.string(forKey: Keys.recordingResolution) ?? "") ?? .hd1080
    }
}
