import Combine
import UIKit
import WebKit

/// Owns the single WKWebView shared by the phone and the car screen.
/// A view can only live in one hierarchy, so the web view moves to the car
/// window while CarPlay is connected and back to the phone afterwards.
final class BrowserEngine: NSObject, ObservableObject {
    static let shared = BrowserEngine()
    static let homeURL = URL(string: "https://m.youtube.com")!

    let webView: WKWebView

    @Published private(set) var currentURL: URL?
    @Published private(set) var pageTitle = ""
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var isCarConnected = false
    @Published private(set) var isVideoFill = false
    /// Virtual mouse pointer on the car screen, in web view coordinates.
    @Published private(set) var cursorPosition: CGPoint = .zero

    private var observations: [NSKeyValueObservation] = []

    private override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false
        if #available(iOS 15.4, *) {
            // Element fullscreen would jump to the phone screen; use the CSS fill mode instead.
            config.preferences.isElementFullscreenEnabled = false
        }
        config.userContentController.addUserScript(
            WKUserScript(source: Scripts.forceInlineVideo, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        )

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = .black
        webView.isOpaque = false

        super.init()
        webView.navigationDelegate = self
        observeWebView()
        webView.load(URLRequest(url: Self.homeURL))
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.url, options: [.initial, .new]) { [weak self] web, _ in
                DispatchQueue.main.async { self?.currentURL = web.url }
            },
            webView.observe(\.title, options: [.initial, .new]) { [weak self] web, _ in
                DispatchQueue.main.async { self?.pageTitle = web.title ?? "" }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] web, _ in
                DispatchQueue.main.async { self?.canGoBack = web.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] web, _ in
                DispatchQueue.main.async { self?.canGoForward = web.canGoForward }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] web, _ in
                DispatchQueue.main.async { self?.isLoading = web.isLoading }
            },
        ]
    }

    // MARK: - Hosting

    func attach(to container: UIView) {
        guard webView.superview !== container else { return }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(webView, at: 0)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    func carDidConnect(container: UIView) {
        isCarConnected = true
        attach(to: container)
    }

    func carDidDisconnect() {
        isCarConnected = false
        // The phone's WebViewContainer re-attaches it on its next update.
        webView.removeFromSuperview()
    }

    // MARK: - Navigation

    func open(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let url = URL(string: text), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            load(url)
        } else if !text.contains(" "), text.contains("."), let url = URL(string: "https://" + text) {
            load(url)
        } else {
            var components = URLComponents(string: "https://m.youtube.com/results")!
            components.queryItems = [URLQueryItem(name: "search_query", value: text)]
            load(components.url!)
        }
    }

    func load(_ url: URL) { webView.load(URLRequest(url: url)) }
    func goHome() { load(Self.homeURL) }
    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }
    func stopLoading() { webView.stopLoading() }

    // MARK: - Video control

    func togglePlayPause() { run(Scripts.togglePlayPause) }
    func seek(by seconds: Double) { run(Scripts.seek(by: seconds)) }

    func toggleVideoFill() {
        isVideoFill.toggle()
        run(Scripts.videoFill(isVideoFill))
    }

    // MARK: - Pointer & scrolling (used when the page is on the car screen)

    func centerCursorIfNeeded() {
        let bounds = webView.bounds
        guard !bounds.isEmpty else { return }
        if cursorPosition == .zero || !bounds.contains(cursorPosition) {
            cursorPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        let bounds = webView.bounds
        guard !bounds.isEmpty else { return }
        cursorPosition = CGPoint(
            x: min(max(cursorPosition.x + dx, bounds.minX), bounds.maxX - 1),
            y: min(max(cursorPosition.y + dy, bounds.minY), bounds.maxY - 1)
        )
    }

    func scroll(dx: CGFloat, dy: CGFloat) {
        let scrollView = webView.scrollView
        let maxX = max(scrollView.contentSize.width - scrollView.bounds.width, 0)
        let maxY = max(scrollView.contentSize.height - scrollView.bounds.height, 0)
        var offset = scrollView.contentOffset
        offset.x = min(max(offset.x + dx, 0), maxX)
        offset.y = min(max(offset.y + dy, 0), maxY)
        scrollView.setContentOffset(offset, animated: false)
    }

    func clickAtCursor() {
        // Points -> CSS pixels; 1:1 on responsive pages, scaled on zoomed-out desktop pages.
        let zoom = max(webView.scrollView.zoomScale, 0.01)
        run(Scripts.click(x: cursorPosition.x / zoom, y: cursorPosition.y / zoom))
    }

    private func run(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}

extension BrowserEngine: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isVideoFill { run(Scripts.videoFill(true)) }
    }
}

private enum Scripts {
    static let forceInlineVideo = """
    (function () {
      function mark() {
        document.querySelectorAll('video').forEach(function (v) {
          v.setAttribute('playsinline', '');
          v.setAttribute('webkit-playsinline', '');
        });
      }
      mark();
      new MutationObserver(mark).observe(document.documentElement, { childList: true, subtree: true });
    })();
    """

    static let togglePlayPause = """
    (function () {
      var v = document.querySelector('video');
      if (!v) return;
      if (v.paused) { v.play(); } else { v.pause(); }
    })();
    """

    static func seek(by seconds: Double) -> String {
        """
        (function () {
          var v = document.querySelector('video');
          if (!v) return;
          v.currentTime = Math.max(0, v.currentTime + (\(seconds)));
        })();
        """
    }

    static func videoFill(_ enabled: Bool) -> String {
        guard enabled else {
            return "(function(){var s=document.getElementById('bp-fill');if(s)s.remove();})();"
        }
        let css = [
            "html,body{overflow:hidden!important;background:#000!important}",
            "#player-container-id,.player-container,ytm-player,#movie_player{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;max-height:none!important;padding:0!important;margin:0!important;z-index:2147483646!important;background:#000!important;transform:none!important}",
            "video{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;object-fit:contain!important;z-index:2147483647!important;background:#000!important}",
        ].joined()
        return """
        (function () {
          var s = document.getElementById('bp-fill');
          if (!s) { s = document.createElement('style'); s.id = 'bp-fill'; document.head.appendChild(s); }
          s.textContent = '\(css)';
        })();
        """
    }

    static func click(x: CGFloat, y: CGFloat) -> String {
        """
        (function (x, y) {
          var el = document.elementFromPoint(x, y);
          if (!el) return false;
          var o = { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y };
          try { el.dispatchEvent(new PointerEvent('pointerdown', o)); } catch (e) {}
          el.dispatchEvent(new MouseEvent('mousedown', o));
          try { el.dispatchEvent(new PointerEvent('pointerup', o)); } catch (e) {}
          el.dispatchEvent(new MouseEvent('mouseup', o));
          el.dispatchEvent(new MouseEvent('click', o));
          return true;
        })(\(x), \(y));
        """
    }
}
