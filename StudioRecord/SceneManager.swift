import Foundation

enum AppScene: Int, CaseIterable {
    case camera  = 1
    case window  = 2
    case browser = 3
    case standby = 4

    var title: String {
        switch self {
        case .camera:  return "מצלמה"
        case .window:  return "חלון"
        case .browser: return "קישור"
        case .standby: return "המתנה"
        }
    }

    var icon: String {
        switch self {
        case .camera:  return "camera"
        case .window:  return "macwindow"
        case .browser: return "globe"
        case .standby: return "pause.rectangle"
        }
    }

    var hasFloatingCircle: Bool {
        self == .window || self == .browser
    }
}

class SceneManager: ObservableObject {
    @Published var activeScene: AppScene = .camera
    private(set) var previousNonStandbyScene: AppScene = .camera

    func setScene(_ scene: AppScene) {
        if activeScene != .standby { previousNonStandbyScene = activeScene }
        activeScene = scene
    }

    func toggleStandby() {
        if activeScene == .standby {
            activeScene = previousNonStandbyScene
        } else {
            previousNonStandbyScene = activeScene
            activeScene = .standby
        }
    }
}
