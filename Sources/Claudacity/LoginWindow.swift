import AppKit
import WebKit

class LoginWindow: NSWindow, WKHTTPCookieStoreObserver, WKUIDelegate {
    private var webView: WKWebView!
    private var onSessionKey: ((String) -> Void)?
    private(set) var didExtractKey = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    convenience init(onSessionKey: @escaping (String) -> Void) {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                  styleMask: [.titled, .closable, .resizable],
                  backing: .buffered,
                  defer: false)
        self.onSessionKey = onSessionKey
        self.isReleasedWhenClosed = false
        title = "Sign In to Claude"
        center()

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let script = WKUserScript(source: """
            new MutationObserver(() => {
                document.getElementById('credential_picker_container')?.remove();
                document.querySelectorAll('button').forEach(b => {
                    if (/^reject$/i.test(b.textContent.trim())) b.click();
                });
            }).observe(document.body || document.documentElement, { childList: true, subtree: true });
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        contentView = webView

        // Clear stale claude.ai cookies before loading, then start observing
        let store = webView.configuration.websiteDataStore.httpCookieStore
        store.getAllCookies { [weak self] cookies in
            let group = DispatchGroup()
            for cookie in cookies where cookie.domain.contains("claude.ai") {
                group.enter()
                store.delete(cookie) { group.leave() }
            }
            group.notify(queue: .main) {
                store.add(self!)
                self?.webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
            }
        }
    }

    // Handle popups (Google SSO) by loading in the same web view
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil || !(navigationAction.targetFrame?.isMainFrame ?? false) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self, self.onSessionKey != nil else { return }
            guard let key = cookies.first(where: { $0.name == "sessionKey" && $0.domain.contains("claude.ai") })?.value,
                  !key.isEmpty else { return }
            DispatchQueue.main.async {
                self.didExtractKey = true
                self.onSessionKey?(key)
                self.onSessionKey = nil
            }
        }
    }
}
