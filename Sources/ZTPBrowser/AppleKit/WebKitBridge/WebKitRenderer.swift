import Foundation
import WebKit
@preconcurrency import AppKit

public final class WebKitRenderer: NSObject, @unchecked Sendable {

    public enum RenderError: Error, Sendable {
        case navigationFailed(String)
        case timeout
        case screenshotFailed
        case pdfFailed
        case javaScriptError(String)
    }

    // MARK: - Public API

    public static func screenshot(url: URL, viewport: Viewport, timeoutMs: Int = 10000, settleMs: Int = 500) async throws -> Data {
        try await performScreenshot(url: url, viewport: viewport, timeoutMs: timeoutMs, settleMs: settleMs)
    }

    public static func pdf(url: URL, viewport: Viewport, timeoutMs: Int = 10000, settleMs: Int = 500) async throws -> Data {
        try await performPDF(url: url, viewport: viewport, timeoutMs: timeoutMs, settleMs: settleMs)
    }

    public static func evaluateJavaScript(url: URL, script: String, timeoutMs: Int = 10000) async throws -> String {
        try await performJS(url: url, script: script, timeoutMs: timeoutMs)
    }

    // MARK: - Main Actor Implementations

    @MainActor
    private static func ensureAppRunning() {
        if NSApp == nil {
            let _ = NSApplication.shared
            NSApp?.setActivationPolicy(.accessory)
        }
    }

    @MainActor
    private static func createWebView(viewport: Viewport, timeoutMs: Int) -> WKWebView {
        ensureAppRunning()

        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: viewport.width, height: viewport.height),
            configuration: config
        )
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    @MainActor
    private static func loadAndWait(webView: WKWebView, url: URL, timeoutMs: Int, settleMs: Int) async throws {
        let request = URLRequest(url: url, timeoutInterval: Double(timeoutMs) / 1000.0)
        webView.load(request)
        try await waitForNavigation(webView: webView, timeoutMs: timeoutMs)
        // Rendering/network settle period (tuned per wait strategy by the caller).
        try await Task.sleep(for: .milliseconds(max(0, settleMs)))
    }

    @MainActor
    private static func performScreenshot(url: URL, viewport: Viewport, timeoutMs: Int, settleMs: Int = 500) async throws -> Data {
        let webView = createWebView(viewport: viewport, timeoutMs: timeoutMs)

        try await loadAndWait(webView: webView, url: url, timeoutMs: timeoutMs, settleMs: settleMs)

        let snapshotConfig = WKSnapshotConfiguration()
        snapshotConfig.snapshotWidth = NSNumber(value: viewport.width)

        let image: NSImage
        do {
            image = try await webView.takeSnapshot(configuration: snapshotConfig)
        } catch {
            throw RenderError.screenshotFailed
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.screenshotFailed
        }

        return pngData
    }

    @MainActor
    private static func performPDF(url: URL, viewport: Viewport, timeoutMs: Int, settleMs: Int = 500) async throws -> Data {
        let webView = createWebView(viewport: viewport, timeoutMs: timeoutMs)

        try await loadAndWait(webView: webView, url: url, timeoutMs: timeoutMs, settleMs: settleMs)

        let pdfConfig = WKPDFConfiguration()
        pdfConfig.rect = CGRect(x: 0, y: 0, width: viewport.width, height: viewport.height)

        let pdfData: Data
        do {
            pdfData = try await webView.pdf(configuration: pdfConfig)
        } catch {
            throw RenderError.pdfFailed
        }

        return pdfData
    }

    @MainActor
    private static func performJS(url: URL, script: String, timeoutMs: Int) async throws -> String {
        let viewport = Viewport.desktop
        let webView = createWebView(viewport: viewport, timeoutMs: timeoutMs)

        try await loadAndWait(webView: webView, url: url, timeoutMs: timeoutMs, settleMs: 500)

        let result: Any?
        do {
            result = try await webView.evaluateJavaScript(script)
        } catch {
            throw RenderError.javaScriptError(error.localizedDescription)
        }

        return String(describing: result ?? "")
    }

    // MARK: - Navigation Waiting

    @MainActor
    private static func waitForNavigation(webView: WKWebView, timeoutMs: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = NavigationWaiter(continuation: continuation)
            webView.navigationDelegate = delegate

            // Prevent delegate from being deallocated before callback fires
            objc_setAssociatedObject(webView, "navigationWaiter", delegate, .OBJC_ASSOCIATION_RETAIN)

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) { [weak delegate] in
                guard let delegate = delegate, !delegate.finished else { return }
                delegate.finished = true
                continuation.resume(throwing: RenderError.timeout)
            }
        }
    }
}

// MARK: - NavigationWaiter

@MainActor
private class NavigationWaiter: NSObject, WKNavigationDelegate {
    var finished = false
    let continuation: CheckedContinuation<Void, Error>

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !finished else { return }
        finished = true
        continuation.resume()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !finished else { return }
        finished = true
        continuation.resume(throwing: WebKitRenderer.RenderError.navigationFailed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !finished else { return }
        finished = true
        continuation.resume(throwing: WebKitRenderer.RenderError.navigationFailed(error.localizedDescription))
    }
}
