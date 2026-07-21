import AppKit

extension Notification.Name {
    static let studioSwitchScene     = Notification.Name("studio.switchScene")
    static let studioToggleCircle    = Notification.Name("studio.toggleCircle")
    static let studioToggleMic       = Notification.Name("studio.toggleMic")
    static let studioToggleRecording = Notification.Name("studio.toggleRecording")
    static let studioToggleStandby   = Notification.Name("studio.toggleStandby")
    static let studioToggleBroadcast = Notification.Name("studio.toggleBroadcast")
    static let studioTogglePanel     = Notification.Name("studio.togglePanel")
}

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "record.circle",
                                            accessibilityDescription: "Studio Record")
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(make("מצלמה",               sel: #selector(scene1),           key: "1"))
        menu.addItem(make("חלון",                 sel: #selector(scene2),           key: "2"))
        menu.addItem(make("דפדפן",                sel: #selector(scene3),           key: "3"))
        menu.addItem(make("מצב המתנה",            sel: #selector(standby),          key: "s"))
        menu.addItem(.separator())
        menu.addItem(make("הסתר/הצג עיגול",       sel: #selector(toggleCircle),     key: "h"))
        menu.addItem(make("השתק/בטל מיקרופון",    sel: #selector(toggleMic),        key: "m"))
        menu.addItem(make("התחל/עצור הקלטה",      sel: #selector(toggleRecording),  key: "r"))
        menu.addItem(make("שידור הפעל/כבה",        sel: #selector(toggleBroadcast),  key: "b"))
        menu.addItem(.separator())
        menu.addItem(make("פאנל שליטה צף",         sel: #selector(togglePanel),      key: "p"))
        menu.addItem(.separator())
        menu.addItem(make("סגור",                  sel: #selector(quit),             key: "q",
                          mods: [.command]))

        return menu
    }

    private func make(_ title: String, sel: Selector, key: String,
                      mods: NSEvent.ModifierFlags = [.control, .option]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        item.target  = self
        item.isEnabled = true
        return item
    }

    @objc private func scene1()           { post(.studioSwitchScene, AppScene.camera)  }
    @objc private func scene2()           { post(.studioSwitchScene, AppScene.window)  }
    @objc private func scene3()           { post(.studioSwitchScene, AppScene.browser) }
    @objc private func standby()          { post(.studioToggleStandby) }
    @objc private func toggleCircle()     { post(.studioToggleCircle) }
    @objc private func toggleMic()        { post(.studioToggleMic) }
    @objc private func toggleRecording()  { post(.studioToggleRecording) }
    @objc private func toggleBroadcast()  { post(.studioToggleBroadcast) }
    @objc private func togglePanel()      { post(.studioTogglePanel) }
    @objc private func quit()             { NSApp.terminate(nil) }

    private func post(_ name: Notification.Name, _ obj: Any? = nil) {
        NotificationCenter.default.post(name: name, object: obj)
    }
}
