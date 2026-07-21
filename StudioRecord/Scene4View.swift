import SwiftUI
import AppKit

class StandbyState: ObservableObject {
    @Published var image:   NSImage? = nil
    @Published var message: String   = "בהמתנה לשידור"

    static let messages = ["בהמתנה לשידור", "מתחילים בקרוב", "עצרנו לרגע", "חוזרים מיד"]

    init() { loadSaved() }

    // Called from ControlBarView's fileImporter result
    func setImage(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let img = NSImage(contentsOf: url) else { return }

        // Copy to Application Support so it survives app restarts
        if let destPath = saveImageToSupport(img) {
            AppPersistence.save(standbyImagePath: destPath)
        }
        self.image = img
    }

    func clearImage() {
        image = nil
        AppPersistence.save(standbyImagePath: nil)
    }

    private func saveImageToSupport(_ img: NSImage) -> String? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory,
                                    in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("StudioRecord", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("standby_image.png")

        guard let tiff   = img.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png    = bitmap.representation(using: .png, properties: [:]) else { return nil }
        try? png.write(to: dest)
        return dest.path
    }

    private func loadSaved() {
        if let path = AppPersistence.loadStandbyImagePath(),
           FileManager.default.fileExists(atPath: path) {
            image = NSImage(contentsOfFile: path)
        }
    }
}

struct Scene4View: View {
    @ObservedObject var state: StandbyState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                if let img = state.image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 520, maxHeight: 320)
                        .cornerRadius(8)
                }

                if !state.message.isEmpty {
                    Text(state.message)
                        .font(.system(size: 38, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
