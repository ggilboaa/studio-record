import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("הגדרות")
                    .font(.headline)
                Spacer()
                Button("סגור") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                Section("הקלטות") {
                    HStack {
                        Text("תיקיית שמירה")
                        Spacer()
                        Text(settings.saveFolder.lastPathComponent)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Button("שנה...") { chooseSaveFolder() }
                            .buttonStyle(.bordered)
                    }

                    Picker("פורמט אודיו", selection: $settings.separateAudioTracks) {
                        Text("ערוץ ממוקסס אחד").tag(false)
                        Text("ערוצים נפרדים (מיקרופון + מערכת)").tag(true)
                    }

                    Picker("רזולוציית הקלטה", selection: $settings.recordingResolution) {
                        ForEach(RecordingResolution.allCases, id: \.rawValue) { res in
                            Text(res.title).tag(res)
                        }
                    }
                }

                Section("לכידת חלון") {
                    Picker("מצב מילוי", selection: $settings.windowFillMode) {
                        ForEach(WindowFillMode.allCases, id: \.rawValue) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                Section("קיצורי מקלדת (⌃⌥ + מקש)") {
                    shortcutRow("סצנה 1 / 2 / 3",      key: "1 / 2 / 3")
                    shortcutRow("הסתר/הצג עיגול",        key: "H")
                    shortcutRow("התחל/עצור הקלטה",       key: "R")
                    shortcutRow("שידור הפעל/כבה",         key: "B")
                    shortcutRow("מצב המתנה",             key: "S")
                    shortcutRow("השתק/בטל מיקרופון",      key: "M")
                    shortcutRow("פאנל צף הצג/הסתר",      key: "P")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 460, height: 520)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles         = false
        panel.canChooseDirectories   = true
        panel.allowsMultipleSelection = false
        panel.message = "בחר תיקייה לשמירת הקלטות"
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolder = url
        }
    }

    private func shortcutRow(_ title: String, key: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("⌃⌥ \(key)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
        }
    }
}
