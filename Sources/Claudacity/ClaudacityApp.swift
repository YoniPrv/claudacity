import SwiftUI
import AppKit

@main
struct ClaudacityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let service = UsageService()
    private var usage: UsageData?
    private var error: (msg: String, help: [String]?)?

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
            // Color based on time to reset: green when close to reset, red when far
            let seconds = usage?.resetsAt?.timeIntervalSinceNow ?? 0
            let ratio = min(1, max(0, seconds / 18000)) // 18000s = 5 hour window
            let hue = 0.33 * (1 - ratio) // 0.33 (green) near reset, 0.0 (red) far from reset
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
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let keyItem = NSMenuItem(title: "Set Session Key...", action: #selector(setKeyClicked), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(keyItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func refreshClicked() { refresh() }

    @objc private func setKeyClicked() {
        let alert = NSAlert()
        alert.messageText = "Set Session Key"
        alert.informativeText = "From claude.ai: Cmd+Opt+I > Storage > Cookies > sessionKey"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "Paste session key"
        alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn {
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { service.setKey(key); refresh() }
        }
    }
}
