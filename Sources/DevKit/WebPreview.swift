import SwiftUI
import WebKit

struct WebPreview: NSViewRepresentable {
    var html: String
    var javaScript: Bool
    var width: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = javaScript
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
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

    final class Coordinator {
        var lastHTML = ""
        var lastJS = true
    }
}
