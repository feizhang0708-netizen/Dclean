import AppKit
import WebKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var bridge: Bridge!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        // 状态栏
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "DC"
            btn.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        }
        buildStatusMenu()

        // 窗口
        let r = NSRect(x: 0, y: 0, width: 880, height: 640)
        window = NSWindow(contentRect: r, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Dclean"
        window.center()
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 0.024, green: 0.043, blue: 0.078, alpha: 1)
        window.minSize = NSSize(width: 780, height: 540)
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true

        let config = WKWebViewConfiguration()
        bridge = Bridge(); config.userContentController.add(bridge, name: "bridge")
        let webView = DWebView(frame: r, configuration: config)
        bridge.webView = webView
        webView.setValue(false, forKey: "drawsBackground")

        let html = loadHTML()
        webView.loadHTMLString(html, baseURL: nil)
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - 状态栏菜单

    func buildStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示 Dclean", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        if #available(macOS 13.0, *) {
            launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            launchItem.state = .off
            launchItem.isEnabled = false
        }
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 Dclean", action: #selector(terminateApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    sender.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    sender.state = .on
                }
            } catch {
                print("SMAppService error: \(error)")
            }
        }
    }

    @objc func terminateApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Dock 图标重开

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    // MARK: - 生命周期

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - HTML 加载

    func loadHTML() -> String {
        // 优先从 .app bundle 加载
        if let url = Bundle.main.url(forResource: "UI", withExtension: "html", subdirectory: "Assets") {
            if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        }
        // 开发模式：从 module bundle 加载
        if let url = Bundle.module.url(forResource: "UI", withExtension: "html", subdirectory: "Assets") {
            if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        }
        // 直接从文件系统加载（SPM 开发模式）
        let srcDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        if let url = URL(string: "Resources/Assets/UI.html", relativeTo: srcDir) {
            if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        }
        fatalError("找不到 UI.html — 请检查 Resources/Assets/ 目录")
    }
}
