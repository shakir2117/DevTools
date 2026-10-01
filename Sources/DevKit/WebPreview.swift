import SwiftUI
import WebKit
import AppKit

struct WebPreview: NSViewRepresentable {
    var html: String
    var javaScript: Bool
    var width: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = javaScript
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(true, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .white
        webView.layer?.backgroundColor = NSColor.white.cgColor
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = javaScript
        if context.coordinator.lastHTML != html || context.coordinator.lastJS != javaScript {
            context.coordinator.lastHTML = html
            context.coordinator.lastJS = javaScript
            webView.loadHTMLString(html, baseURL: nil)
        }
        webView.frame.size.width = width
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""
        var lastJS = true

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            if navigationAction.navigationType == .linkActivated || scheme == "file" || scheme == "javascript" {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
