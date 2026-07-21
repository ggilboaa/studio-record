import SwiftUI
import ScreenCaptureKit
import AppKit

private enum PickerTab: String { case windows = "חלונות"; case cameras = "מצלמות" }

struct WindowPickerView: View {
    @ObservedObject var screenCapture: ScreenCaptureManager
    @Binding var isPresented: Bool

    @State private var tab: PickerTab = .windows
    @State private var searchText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            if screenCapture.permissionDenied {
                permissionView
            } else if screenCapture.availableWindows.isEmpty && tab == .windows {
                ProgressView("טוען חלונות פתוחים…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                windowGrid
            }

            footer
        }
        .frame(width: 760, height: 560)
        .background(Color.white)
        .task { await screenCapture.refreshWindows() }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("בחירת מקור לסצנה 2")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.appLabel)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    ZStack {
                        Circle().fill(Color(white: 0.925)).frame(width: 26, height: 26)
                        Text("×").font(.system(size: 14)).foregroundStyle(Color.appLabel4)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 4)

            HStack(spacing: 14) {
                // Tab switcher
                HStack(spacing: 3) {
                    ForEach([PickerTab.windows, .cameras], id: \.rawValue) { t in
                        let selected = tab == t
                        Button { tab = t } label: {
                            Text(t.rawValue)
                                .font(.system(size: 13.5, weight: selected ? .bold : .semibold))
                                .foregroundStyle(selected ? Color.appBlueText : Color.appLabel3)
                                .padding(.horizontal, 20).padding(.vertical, 7)
                                .background(
                                    Group {
                                        if selected {
                                            RoundedRectangle(cornerRadius: 7).fill(Color.white)
                                                .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.appSegment)
                .clipShape(RoundedRectangle(cornerRadius: 9))

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.appLabel5)
                        .font(.system(size: 13))
                    TextField("חיפוש…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5))
                        .environment(\.layoutDirection, .rightToLeft)
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color(white: 0.941))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Grid

    private var windowGrid: some View {
        ScrollView {
            if tab == .cameras {
                Text("בחר מצלמה מהסרגל הכלים הראשי")
                    .foregroundStyle(Color.appLabel4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filteredWindows, id: \.windowID) { window in
                        WindowThumbnailCell(
                            window: window,
                            isSelected: screenCapture.selectedWindow?.windowID == window.windowID
                        ) {
                            screenCapture.selectWindow(window)
                            isPresented = false
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredWindows: [SCWindow] {
        guard !searchText.isEmpty else { return screenCapture.availableWindows }
        let q = searchText.lowercased()
        return screenCapture.availableWindows.filter { w in
            (w.owningApplication?.applicationName.lowercased().contains(q) ?? false)
            || (w.title?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("מילוי החלון בפריים נקבע בהגדרות: Fit / Fill")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.appLabel5)
            Spacer()
            Button("ביטול") { isPresented = false }
                .buttonStyle(.plain)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color.appLabel2)
                .padding(.horizontal, 20).padding(.vertical, 9)
                .background(Color(white: 0.925))
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .overlay(Divider().frame(maxHeight: .infinity, alignment: .top), alignment: .top)
    }

    // MARK: - Permission view

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
}

// MARK: - Thumbnail cell

private struct WindowThumbnailCell: View {
    let window: SCWindow
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                thumbnailContainer
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.owningApplication?.applicationName ?? "אפליקציה")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color.appLabel)
                        .lineLimit(1)
                    if let title = window.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appLabel5)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var thumbnailContainer: some View {
        ZStack(alignment: .topLeading) {
            // Thumbnail area (4:3 aspect)
            Color(white: 0.93)
                .aspectRatio(4/3, contentMode: .fit)
                .overlay(appIconOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isSelected ? Color.appBlue : Color.black.opacity(0.08),
                                lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: .black.opacity(isSelected ? 0.15 : 0.1), radius: isSelected ? 8 : 4, y: isSelected ? 4 : 2)

            if isSelected {
                ZStack {
                    Circle().fill(Color.appBlue).frame(width: 22, height: 22)
                    Text("✓").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                }
                .padding(8)
            }
        }
    }

    @ViewBuilder
    private var appIconOverlay: some View {
        if let bid = window.owningApplication?.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 32))
                .foregroundStyle(Color.appLabel5)
        }
    }
}
