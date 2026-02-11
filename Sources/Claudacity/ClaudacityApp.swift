import SwiftUI
import AppKit

@main
struct ClaudacityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let service = UsageService()
    private var usage: UsageData?
    private var error: (msg: String, help: [String]?)?
    private var loginWindow: LoginWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⏳"
        refresh()
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        Task {
            do {
                let u = try await service.fetch()
                await MainActor.run { self.usage = u; self.error = nil; self.updateUI() }
            } catch {
                let e = error as? UsageService.Err
                await MainActor.run { self.error = (error.localizedDescription, e?.helpSteps); self.updateUI() }
            }
        }
    }

    private func updateUI() {
        if error != nil {
            statusItem.button?.title = "⚠️"
        } else {
            let icon = usage?.icon ?? "○"
            let pct = Int(usage?.percentage ?? 0)
            // Color based on usage: green (low usage) → red (high usage)
            let ratio = min(1, max(0, (usage?.percentage ?? 0) / 100))
            let hue = 0.33 * (1 - ratio) // 0.33 (green) at 0%, 0.0 (red) at 100%
            let color = NSColor(hue: hue, saturation: 0.9, brightness: 0.85, alpha: 1.0)
            let str = NSMutableAttributedString()
            str.append(NSAttributedString(string: icon, attributes: [.foregroundColor: color]))
            str.append(NSAttributedString(string: " \(pct)%"))
            statusItem.button?.attributedTitle = str
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "\(usage?.planName ?? "Claude") Usage", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        if let e = error {
            menu.addItem(NSMenuItem(title: "⚠️ \(e.msg)", action: nil, keyEquivalent: ""))
            e.help?.forEach { menu.addItem(NSMenuItem(title: "  \($0)", action: nil, keyEquivalent: "")) }
        } else if let u = usage {
            menu.addItem(NSMenuItem(title: "Used: \(Int(u.percentage))%", action: nil, keyEquivalent: ""))
            if let t = u.timeUntilReset, let time = u.resetTimeString {
                menu.addItem(NSMenuItem(title: "Resets: \(t) (\(time))", action: nil, keyEquivalent: ""))
            }
        }

        menu.addItem(.separator())
        let isSignedIn = usage != nil
        if isSignedIn {
            let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)
            let signOutItem = NSMenuItem(title: "Sign Out", action: #selector(signOutClicked), keyEquivalent: "")
            signOutItem.target = self
            menu.addItem(signOutItem)
        } else {
            let signInItem = NSMenuItem(title: "Sign In to Claude...", action: #selector(signInClicked), keyEquivalent: "")
            signInItem.target = self
            menu.addItem(signInItem)
        }
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func refreshClicked() { refresh() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func signInClicked() {
        NSApp.setActivationPolicy(.regular)
        loginWindow = LoginWindow { [weak self] key in
            self?.service.setKey(key)
            self?.loginWindow?.close()
        }
        loginWindow?.delegate = self
        loginWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        let didSignIn = loginWindow?.didExtractKey ?? false
        loginWindow = nil
        NSApp.setActivationPolicy(.accessory)
        if didSignIn { refresh() }
    }

    @objc private func signOutClicked() {
        service.clearKey()
        usage = nil
        error = ("Signed out", ["Click 'Sign In to Claude...' to authenticate"])
        updateUI()
    }
}
