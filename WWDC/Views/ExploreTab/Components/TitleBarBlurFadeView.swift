import Cocoa

final class TitleBarBlurFadeView: NSView {

    static var isSupported: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 100) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setup() {
        guard Self.isSupported else { return }

        guard let blurLayer = CALayer.load(assetNamed: "VariableBlur-Top") else {
            assertionFailure("Failed to load VariableBlur-Top layer asset")
            return
        }

        wantsLayer = true
        layer = blurLayer
    }

}
