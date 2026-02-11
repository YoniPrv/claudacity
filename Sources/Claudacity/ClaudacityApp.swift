import SwiftUI
import AppKit
import UserNotifications

@main
struct ClaudacityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private let service = UsageService()
    private var usage: UsageData?
    private var error: (msg: String, help: [String]?)?
    private var loginWindow: LoginWindow?
    private var notifiedThresholds = Set<Int>()
    private var notifiedReset = false
    private static let notificationsEnabledKey = "notificationsEnabled"
    private var notificationsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.notificationsEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.notificationsEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.notificationsEnabledKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⏳"
        let notifCenter = UNUserNotificationCenter.current()
        notifCenter.delegate = self
        notifCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        }
        refresh()
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        Task {
            do {
                let u = try await service.fetch()
                await MainActor.run {
                    self.usage = u; self.error = nil; self.updateUI()
                    self.checkThresholds(u)
                }
            } catch {
                let e = error as? UsageService.Err
                await MainActor.run { self.error = (error.localizedDescription, e?.helpSteps); self.updateUI() }
            }
        }
    }

    private func checkThresholds(_ u: UsageData) {
        guard notificationsEnabled else { return }
        let pct = Int(u.percentage)

        // Reset tracking when usage drops below 50% (new cycle)
        if pct < 50 {
            notifiedThresholds.removeAll()
            notifiedReset = false
            return
        }

        // Check if quota has reset (usage was high, now low)
        if let resetsAt = u.resetsAt, resetsAt.timeIntervalSinceNow <= 0, !notifiedReset {
            notifiedReset = true
            sendNotification(title: "Usage has reset", body: "\(u.planName) quota has reset. You're good to go!")
            notifiedThresholds.removeAll()
            return
        }

        let thresholds: [(level: Int, title: String, body: String)] = [
            (50, "Halfway there", "\(u.planName) usage is at \(pct)%."),
            (80, "Usage is getting high", "\(u.planName) usage is at \(pct)%. Consider pacing your usage."),
            (90, "Almost at the limit", "\(u.planName) usage is at \(pct)%.\(u.timeUntilReset.map { " Resets in \($0)." } ?? "")"),
        ]

        for t in thresholds where pct >= t.level && !notifiedThresholds.contains(t.level) {
            notifiedThresholds.insert(t.level)
            sendNotification(title: t.title, body: t.body)
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
        let notifItem = NSMenuItem(title: "Notifications", action: #selector(toggleNotifications), keyEquivalent: "")
        notifItem.target = self
        notifItem.state = notificationsEnabled ? .on : .off
        menu.addItem(notifItem)
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
        notifiedThresholds.removeAll()
        notifiedReset = false
        error = ("Signed out", ["Click 'Sign In to Claude...' to authenticate"])
        updateUI()
    }

    @objc private func toggleNotifications() {
        notificationsEnabled.toggle()
        updateUI()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
