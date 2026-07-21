import SwiftUI
import ScreenCaptureKit
import AppKit

struct WindowPickerView: View {
    @ObservedObject var screenCapture: ScreenCaptureManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("בחר חלון לשיתוף")
                    .font(.headline)
                Spacer()
                Button("סגור") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if screenCapture.permissionDenied {
                permissionView
            } else if screenCapture.availableWindows.isEmpty {
                ProgressView("טוען חלונות פתוחים...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                windowList
            }
        }
        .frame(width: 420, height: 500)
        .task { await screenCapture.refreshWindows() }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var windowList: some View {
        List(screenCapture.availableWindows, id: \.windowID) { window in
            Button {
                screenCapture.selectWindow(window)
                isPresented = false
            } label: {
                HStack(spacing: 10) {
                    appIcon(for: window.owningApplication?.bundleIdentifier)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(window.owningApplication?.applicationName ?? "אפליקציה")
                            .fontWeight(.medium)
                        if let title = window.title, !title.isEmpty {
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("נדרשת הרשאת הקלטת מסך")
                .font(.headline)
            Text("הגדרות מערכת ← פרטיות ואבטחה ← הקלטת מסך ואודיו מערכת\nסמן ✓ ליד Studio Record")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("פתח הגדרות מערכת") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func appIcon(for bundleID: String?) -> some View {
        if let bid = bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "app.dashed")
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
        }
    }
}
