import SwiftUI
import UIKit

/// Hosts the shared web view on the phone while CarPlay isn't using it.
struct WebViewContainer: UIViewRepresentable {
    let engine: BrowserEngine

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        engine.attach(to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        if !engine.isCarConnected { engine.attach(to: container) }
    }
}
