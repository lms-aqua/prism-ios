import SwiftUI
import WebKit
import UIKit

struct PrismView: View {
    @State private var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            WebView(webView: webView, isLoading: $isLoading, loadError: $loadError)
                .ignoresSafeArea(edges: .bottom)

            if let loadError {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                    Text("Couldn't reach Prism")
                        .font(.title2.bold())
                    Text(loadError)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { loadPrism() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
            } else if isLoading {
                ProgressView("Connecting to Prism...")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task {
            if webView.url == nil { loadPrism() }
        }
    }

    private func loadPrism() {
        loadError = nil
        isLoading = true
        let url = URL(string: "https://prism.codystechcorner.com/")!
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
    }
}

private struct WebView: UIViewRepresentable {
    let webView: WKWebView
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView

        init(_ parent: WebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            fail(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            fail(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.isLoading = false
            parent.loadError = "Prism stopped responding. Try connecting again."
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased() else {
                decisionHandler(.cancel)
                return
            }
            if scheme == "https" && url.host?.lowercased() == "prism.codystechcorner.com" {
                decisionHandler(.allow)
            } else if navigationAction.navigationType == .linkActivated,
                      ["http", "https"].contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Keep same-site links that request a new window inside the app.
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url,
               url.scheme?.lowercased() == "https",
               url.host?.lowercased() == "prism.codystechcorner.com" {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func fail(_ error: Error) {
            let nsError = error as NSError
            guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }
    }
}