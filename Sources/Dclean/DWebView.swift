import WebKit

class DWebView: WKWebView {
    func eval(_ js: String) {
        evaluateJavaScript(js, completionHandler: nil)
    }
}
