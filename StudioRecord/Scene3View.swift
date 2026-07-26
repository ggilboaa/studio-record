import SwiftUI
import WebKit

// MARK: — Navigation state (lifted to ContentView)

class WebNavState: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var canGoBack    = false
    @Published var canGoForward = false
    @Published var displayURL   = ""

    weak var webView: WKWebView?

    // MARK: - Snapshot for recording
    var frameSnapshotHandler: ((CGImage) -> Void)?
    private var snapshotTimer: Timer?

    func startSnapshots() {
        guard snapshotTimer == nil else { return }
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            self?.captureSnapshot()
        }
    }

    func stopSnapshots() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    private func captureSnapshot() {
        guard let wv = webView, let handler = frameSnapshotHandler else { return }
        let config = WKSnapshotConfiguration()
        wv.takeSnapshot(with: config) { image, _ in
            guard let nsImage = image else { return }
            var rect = CGRect(origin: .zero, size: nsImage.size)
            if let cg = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                handler(cg)
            }
        }
    }

    func navigate(to raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s) else { return }
        webView?.load(URLRequest(url: url))
    }

    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload()    { webView?.reload() }

    func prevSlide() { sendKey("ArrowLeft",  code: 37) }
    func nextSlide() { sendKey("ArrowRight", code: 39) }

    private func sendKey(_ key: String, code: Int) {
        let script = """
        (function(){
            var el = document.activeElement || document.body;
            ['keydown','keyup'].forEach(function(t){
                el.dispatchEvent(new KeyboardEvent(t,
                    {key:'\(key)',keyCode:\(code),which:\(code),bubbles:true,cancelable:true}));
            });
        })();
        """
        webView?.evaluateJavaScript(script)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.canGoBack    = webView.canGoBack
            self.canGoForward = webView.canGoForward
            self.displayURL   = webView.url?.absoluteString ?? ""
        }
    }
}

// MARK: — WKWebView wrapper

struct WebViewRepresentable: NSViewRepresentable {
    @ObservedObject var nav: WebNavState

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = nav
        nav.webView = wv
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: — Scene 3

struct Scene3View: View {
    @ObservedObject var nav: WebNavState

    var body: some View {
        WebViewRepresentable(nav: nav)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
