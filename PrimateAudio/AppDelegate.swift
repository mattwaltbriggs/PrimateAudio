import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Main menu

    private func buildMainMenu() {
        let appName = "PrimateAudio"
        let mainMenu = NSMenu()

        // Application menu
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: appName)
        appItem.submenu = appMenu

        let aboutItem = NSMenuItem(title: "About \(appName)", action: #selector(showAbout(_:)), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // File menu
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        fileMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

        // Edit menu
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        NSApp.mainMenu = mainMenu
    }

    // MARK: - About

    @objc func showAbout(_ sender: Any?) {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = "About PrimateAudio"
        window.isReleasedWhenClosed = false
        window.center()

        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]

        let iconView = NSImageView(frame: NSRect(x: 190, y: 440, width: 100, height: 100))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        content.addSubview(iconView)

        let title = NSTextField(labelWithString: "PrimateAudio")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 404, width: 440, height: 26)
        title.autoresizingMask = [.width, .minYMargin]
        content.addSubview(title)

        let version = NSTextField(labelWithString: "Version 1.0 — Unofficial build\nNot affiliated with or endorsed by Monkey's Audio")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor
        version.alignment = .center
        version.maximumNumberOfLines = 2
        version.frame = NSRect(x: 20, y: 362, width: 440, height: 34)
        version.autoresizingMask = [.width, .minYMargin]
        content.addSubview(version)

        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: 440, height: 290))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = licenseText()
        textView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        content.addSubview(scrollView)

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeAbout(_:)))
        closeButton.keyEquivalent = "\r"
        closeButton.bezelStyle = .rounded
        closeButton.frame = NSRect(x: 190, y: 18, width: 100, height: 32)
        closeButton.autoresizingMask = [.minXMargin, .maxXMargin, .maxYMargin]
        content.addSubview(closeButton)

        window.contentView = content
        aboutWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closeAbout(_ sender: Any?) {
        aboutWindow?.close()
    }

    private func licenseText() -> String {
        if let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return "This application bundles libMAC (Monkey's Audio Codec).\n" +
            "Copyright 2000-2026 Matthew T. Ashland. All rights reserved.\n" +
            "Licensed under the BSD 3-Clause License.\n\n" +
            "This is an unofficial, independent front-end and is not affiliated with, " +
            "sponsored by, or endorsed by Monkey's Audio or Matthew T. Ashland."
    }
}