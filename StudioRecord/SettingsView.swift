import SwiftUI
import AppKit

private enum SettingsSection: String, CaseIterable {
    case recording  = "הקלטה ואודיו"
    case general    = "כללי"
    case camera     = "מצלמה"
    case window     = "סצנה 2 — חלון"
    case standby    = "מצב המתנה"
    case shortcuts  = "קיצורי מקלדת"

    var iconName: String {
        switch self {
        case .recording: return "circle.fill"
        case .general:   return "gearshape.fill"
        case .camera:    return "camera.fill"
        case .window:    return "rectangle.fill"
        case .standby:   return "pause.rectangle.fill"
        case .shortcuts: return "keyboard.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .recording: return Color.appBlue
        case .general:   return Color(red: 0.557, green: 0.557, blue: 0.576) // #8e8e93
        case .camera:    return Color(red: 0.204, green: 0.780, blue: 0.349) // #34c759
        case .window:    return Color(red: 0.686, green: 0.322, blue: 0.871) // #af52de
        case .standby:   return Color(red: 0.345, green: 0.337, blue: 0.839) // #5856d6
        case .shortcuts: return Color(red: 0.557, green: 0.557, blue: 0.576)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var isPresented: Bool
    @State private var selectedSection: SettingsSection = .recording
    @State private var showStandbyImagePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // macOS-style title bar
            ZStack {
                LinearGradient(colors: [Color(white: 0.988), Color(white: 0.933)],
                               startPoint: .top, endPoint: .bottom)
                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(Color(red: 1, green: 0.369, blue: 0.341)).frame(width: 12, height: 12)
                        Circle().fill(Color(red: 0.996, green: 0.737, blue: 0.180)).frame(width: 12, height: 12)
                        Circle().fill(Color(red: 0.157, green: 0.784, blue: 0.251)).frame(width: 12, height: 12)
                    }
                    Spacer()
                    Button("סגור") { isPresented = false }
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.appLabel3)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 15)
                Text("הגדרות")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appLabel2)
            }
            .frame(height: 44)
            .overlay(Divider().frame(maxHeight: .infinity, alignment: .bottom), alignment: .bottom)
            .environment(\.layoutDirection, .leftToRight)

            HStack(spacing: 0) {
                // Sidebar
                sidebar

                Divider()

                // Content area
                ScrollView {
                    contentArea
                        .padding(30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            }
        }
        .frame(width: 860, height: 600)
        .environment(\.layoutDirection, .rightToLeft)
        .fileImporter(isPresented: $showStandbyImagePicker, allowedContentTypes: [.image]) { _ in }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 3) {
            ForEach(SettingsSection.allCases, id: \.rawValue) { section in
                SidebarRow(
                    section: section,
                    isSelected: selectedSection == section
                ) { selectedSection = section }
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 220)
        .background(Color.appSidebar)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch selectedSection {
        case .recording:
            recordingContent
        case .camera:
            cameraContent
        case .window:
            windowContent
        case .standby:
            standbyContent
        case .shortcuts:
            shortcutsContent
        default:
            generalContent
        }
    }

    private var recordingContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            formSection(title: "הקלטה") {
                formRow(icon: "folder.fill", iconColor: Color(red: 0.290, green: 0.620, blue: 1.0),
                        label: "תיקיית שמירה") {
                    HStack(spacing: 10) {
                        Text(settings.saveFolder.lastPathComponent)
                            .foregroundStyle(Color.appLabel4).lineLimit(1)
                        formButton("שנה…") { chooseSaveFolder() }
                    }
                }
                Divider().padding(.leading, 16)
                formRow(label: "רזולוציית הקלטה") {
                    Picker("", selection: $settings.recordingResolution) {
                        ForEach(RecordingResolution.allCases, id: \.rawValue) { res in
                            Text(res.title).tag(res)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                Divider().padding(.leading, 16)
                formRow(label: "שם קובץ") {
                    Text("תאריך ושעה אוטומטי")
                        .foregroundStyle(Color.appLabel4)
                        .font(.system(size: 13))
                }
            }

            formSection(title: "אודיו") {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("פורמט אודיו").font(.system(size: 14, weight: .medium))
                            Text("מיקרופון + סאונד מערכת")
                                .font(.system(size: 12)).foregroundStyle(Color.appLabel5)
                        }
                        Spacer()
                        segmentPicker(
                            options: ["ממוקסס · מומלץ", "ערוצים נפרדים"],
                            selectedIndex: Binding(
                                get: { settings.separateAudioTracks ? 1 : 0 },
                                set: { settings.separateAudioTracks = $0 == 1 }
                            )
                        )
                    }
                    .padding(14)
                }
            }
        }
    }

    private var windowContent: some View {
        formSection(title: "מילוי חלון נלכד") {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("אופן מילוי").font(.system(size: 14, weight: .medium))
                        Text("Fit — שמירה על יחס הצד המקורי")
                            .font(.system(size: 12)).foregroundStyle(Color.appLabel5)
                    }
                    Spacer()
                    segmentPicker(
                        options: WindowFillMode.allCases.map(\.title),
                        selectedIndex: Binding(
                            get: { WindowFillMode.allCases.firstIndex(of: settings.windowFillMode) ?? 0 },
                            set: { settings.windowFillMode = WindowFillMode.allCases[$0] }
                        )
                    )
                }
                .padding(14)
            }
        }
    }

    private var standbyContent: some View {
        formSection(title: "מצב המתנה") {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("רקע מצב המתנה").font(.system(size: 14, weight: .medium))
                    Text("תמונה שמוצגת בזמן המתנה — לוגו, שקף \"תיכף מתחילים\".\nבלי תמונה — מסך ברירת מחדל נקי.")
                        .font(.system(size: 12)).foregroundStyle(Color.appLabel5)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                formButton("העלה תמונה…") { showStandbyImagePicker = true }
            }
            .padding(14)
        }
    }

    private var cameraContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("הגדרות המצלמה נמצאות בסרגל הכלים הראשי.")
                .foregroundStyle(Color.appLabel4)
            Text("בחר מצלמה ושנה flip ישירות מהממשק.")
                .foregroundStyle(Color.appLabel5)
                .font(.system(size: 13))
        }
    }

    private var generalContent: some View {
        Text("הגדרות כלליות").foregroundStyle(Color.appLabel4)
    }

    private var shortcutsContent: some View {
        formSection(title: "קיצורי מקלדת (⌃⌥ + מקש)") {
            let rows: [(String, String)] = [
                ("סצנה 1 — מצלמה",      "1"),
                ("סצנה 2 — שיתוף חלון", "2"),
                ("סצנה 3 — קישור",       "3"),
                ("הסתר/הצג עיגול",        "H"),
                ("התחל/עצור הקלטה",       "R"),
                ("שידור הפעל/כבה",         "B"),
                ("מצב המתנה",             "S"),
                ("השתק/בטל מיקרופון",      "M"),
                ("פאנל צף הצג/הסתר",      "P"),
            ]
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(row.0).font(.system(size: 14)).foregroundStyle(Color.appLabel2)
                        Spacer()
                        Text("⌃⌥\(row.1)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.appLabel4)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    if i < rows.count - 1 { Divider().padding(.leading, 14) }
                }
            }
        }
    }

    // MARK: - Form helpers

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Color.appLabel5)
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.black.opacity(0.08), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func formRow<Trailing: View>(icon: String? = nil, iconColor: Color = .clear,
                                         label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(iconColor)
                        .frame(width: 28, height: 24)
                    Image(systemName: icon).font(.system(size: 12)).foregroundStyle(.white)
                }
            }
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.appLabel2)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func formButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.appLabel2)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }

    private func segmentPicker(options: [String], selectedIndex: Binding<Int>) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                let isSelected = selectedIndex.wrappedValue == i
                Button { selectedIndex.wrappedValue = i } label: {
                    Text(opt)
                        .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? Color.appBlueText : Color.appLabel3)
                        .padding(.horizontal, 15).padding(.vertical, 7)
                        .background(
                            Group {
                                if isSelected {
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
    }

    // MARK: - Actions

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "בחר תיקייה לשמירת הקלטות"
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolder = url
        }
    }
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.white.opacity(0.25) : section.iconColor)
                        .frame(width: 22, height: 22)
                    Image(systemName: section.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(section.rawValue)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.appLabel2)
                Spacer()
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.appBlue : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
