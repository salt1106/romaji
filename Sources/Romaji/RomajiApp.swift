import AppKit
import SwiftUI

@main
struct RomajiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let composerModel = ComposerModel()
    private var composerPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var requestLogWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?
    private var previousApp: NSRunningApplication?
    private var previousFocusTarget: FocusTarget?
    private var enabledObserver: NSObjectProtocol?
    private var shortcutObserver: NSObjectProtocol?
    private var languageObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        updateEnabledState()
        enabledObserver = NotificationCenter.default.addObserver(
            forName: .romajiEnabledChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateEnabledState() }
        }
        shortcutObserver = NotificationCenter.default.addObserver(
            forName: .romajiShortcutChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadHotKey() }
        }
        languageObserver = NotificationCenter.default.addObserver(
            forName: .romajiLanguageChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLocalizedUI() }
        }
    }

    func showComposer() {
        guard AppSettings.shared.isEnabled else { return }
        if composerPanel?.isVisible == true {
            dismissComposer()
            return
        }

        previousApp = NSWorkspace.shared.frontmostApplication
        previousFocusTarget = TextInserter.focusTarget()
        composerModel.reset()
        composerModel.onDismiss = { [weak self] in self?.dismissComposer() }
        composerModel.onInsert = { [weak self] text in self?.insert(text) }
        composerModel.onSizeChange = { [weak self] size in
            self?.resizeComposer(to: size)
        }

        let panel = composerPanel ?? makeComposerPanel()
        composerPanel = panel
        position(panel)
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeSettingsWindow()
        }
        guard let window = settingsWindow else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func showRequestLog() {
        if requestLogWindow == nil {
            requestLogWindow = makeRequestLogWindow()
        }
        guard let window = requestLogWindow else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeComposerPanel() -> NSPanel {
        let panel = ComposerPanel(
            contentRect: NSRect(x: 0, y: 0, width: composerModel.panelWidth, height: composerModel.panelHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ComposerView(model: composerModel))
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 24
        panel.contentView?.layer?.cornerCurve = .continuous
        panel.contentView?.layer?.masksToBounds = true
        panel.onCancel = { [weak self] in self?.dismissComposer() }
        panel.onResignKey = { [weak self] in self?.hideComposer() }
        return panel
    }

    private func makeRequestLogWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppSettings.shared.copy.requestLogTitle
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 680, height: 440)
        window.setContentSize(NSSize(width: 860, height: 620))
        window.contentView = NSHostingView(rootView: RequestLogView())
        return window
    }

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppSettings.shared.copy.settingsTitle
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 560)
        window.contentView = NSHostingView(rootView: SettingsView())
        return window
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        panel.setFrameOrigin(
            NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.midY + frame.height * 0.12
            )
        )
    }

    private func resizeComposer(to size: CGSize) {
        guard let panel = composerPanel else { return }
        let oldFrame = panel.frame
        panel.setFrame(
            NSRect(
                x: oldFrame.midX - size.width / 2,
                y: oldFrame.maxY - size.height,
                width: size.width,
                height: size.height
            ),
            display: true,
            animate: panel.isVisible
        )
    }

    private func dismissComposer() {
        composerPanel?.orderOut(nil)
        previousApp?.activate()
    }

    private func hideComposer() {
        composerPanel?.orderOut(nil)
    }

    private func insert(_ text: String) {
        composerPanel?.orderOut(nil)
        TextInserter.insert(
            text,
            into: previousApp,
            focusTarget: previousFocusTarget
        )
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "character.cursor.ibeam",
            accessibilityDescription: "Romaji"
        )

        statusItem = item
        rebuildStatusMenu()
        updateStatusMenu()
    }

    private func rebuildStatusMenu() {
        let copy = AppSettings.shared.copy
        let menu = NSMenu()
        addMenuItem(copy.enableRomaji, action: #selector(toggleEnabled), tag: 1, to: menu)
        menu.addItem(.separator())
        addMenuItem(copy.openComposer, action: #selector(openComposer), tag: 2, to: menu)
        addMenuItem(copy.settings, action: #selector(openSettings), tag: 3, keyEquivalent: ",", to: menu)
        addMenuItem(copy.requestLog, action: #selector(openRequestLog), tag: 4, to: menu)
        menu.addItem(.separator())
        addMenuItem(copy.quit, action: #selector(quit), tag: 5, keyEquivalent: "q", to: menu)
        statusItem?.menu = menu
    }

    private func addMenuItem(
        _ title: String,
        action: Selector,
        tag: Int,
        keyEquivalent: String = "",
        to menu: NSMenu
    ) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.tag = tag
    }

    private func updateEnabledState() {
        if AppSettings.shared.isEnabled {
            if hotKey == nil {
                hotKey = GlobalHotKey(shortcut: AppSettings.shared.openShortcut) { [weak self] in
                    self?.showComposer()
                }
            }
        } else {
            hotKey?.stop()
            hotKey = nil
            composerPanel?.orderOut(nil)
        }
        updateStatusMenu()
    }

    private func updateStatusMenu() {
        guard let item = statusItem, let menu = item.menu else { return }
        item.button?.appearsDisabled = !AppSettings.shared.isEnabled
        menu.item(withTag: 1)?.state = AppSettings.shared.isEnabled ? .on : .off
        menu.item(withTag: 2)?.isEnabled = AppSettings.shared.isEnabled
    }

    private func refreshLocalizedUI() {
        rebuildStatusMenu()
        updateStatusMenu()
        settingsWindow?.title = AppSettings.shared.copy.settingsTitle
        requestLogWindow?.title = AppSettings.shared.copy.requestLogTitle
    }

    private func reloadHotKey() {
        hotKey?.stop()
        hotKey = nil
        updateEnabledState()
    }

    @objc private func toggleEnabled() {
        AppSettings.shared.isEnabled.toggle()
    }

    @objc private func openComposer() { showComposer() }
    @objc private func openSettings() { showSettings() }
    @objc private func openRequestLog() { showRequestLog() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

final class ComposerPanel: NSPanel {
    var onCancel: (() -> Void)?
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func resignKey() {
        super.resignKey()
        DispatchQueue.main.async { [weak self] in
            self?.onResignKey?()
        }
    }
}
