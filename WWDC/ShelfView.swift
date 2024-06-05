import SwiftUI
import AVFoundation

/// This is the view that's shipped in the app, it uses the CA archive.
final class ShelfView: NSView {
    var image: NSImage? {
        didSet {
            guard image != oldValue else { return }

            update(with: image)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private lazy var assetLayer: CALayer = {
        let l = CALayer.load(assetNamed: "Shelf") ?? CALayer()
        l.frame = bounds
        return l
    }()

    private lazy var container: CATransformLayer = {
        assetLayer.sublayer(named: "container", of: CATransformLayer.self) ?? CATransformLayer()
    }()

    private lazy var backgroundLayer: CALayer = {
        container.sublayer(named: "background", of: CALayer.self) ?? CALayer()
    }()

    private lazy var shadowLayer: CALayer = {
        container.sublayer(named: "shadow", of: CALayer.self) ?? CALayer()
    }()

    private lazy var foregroundLayer: CALayer = {
        container.sublayer(named: "foreground", of: CALayer.self) ?? CALayer()
    }()

    private lazy var strokeLayer: CALayer = {
        container.sublayer(named: "stroke", of: CALayer.self) ?? CALayer()
    }()

    private func setup() {
        wantsLayer = true

        container.frame = bounds
        container.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        layer?.addSublayer(container)

        update(with: image)

        installDebugMenuIfNeeded()
    }

    private func update(with image: NSImage?) {
        let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        backgroundLayer.contents = cgImage
        foregroundLayer.contents = cgImage
    }

    override func layout() {
        super.layout()

        guard let image, !image.size.width.isZero, !image.size.height.isZero else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        defer { CATransaction.commit() }

        let imageRect = AVMakeRect(aspectRatio: image.size, insideRect: bounds)

        guard imageRect.width.isFinite, imageRect.height.isFinite else { return }

        foregroundLayer.frame = imageRect
        shadowLayer.frame = imageRect
        strokeLayer.frame = imageRect
        shadowLayer.shadowPath = CGPath(roundedRect: shadowLayer.bounds, cornerWidth: foregroundLayer.cornerRadius, cornerHeight: foregroundLayer.cornerRadius, transform: nil)
    }

    func setBackgroundHidden(_ hidden: Bool, animated: Bool = true) {
        backgroundLayer.removeAllAnimations()

        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = (backgroundLayer.presentation() ?? backgroundLayer).opacity
        fadeAnim.toValue = hidden ? 0 : 1
        fadeAnim.isRemovedOnCompletion = false
        fadeAnim.fillMode = .forwards
        fadeAnim.duration = 0.5
        backgroundLayer.add(fadeAnim, forKey: "fade")
    }

    #if DEBUG
    private static let enableDebugMenu = false

    private lazy var debugMenu = NSMenu(title: "Debug")

    private func installDebugMenuIfNeeded() {
        guard Self.enableDebugMenu else { return }

        let blendModes: [String] = [
            "normalBlendMode",
            "multiplyBlendMode",
            "screenBlendMode",
            "overlayBlendMode",
            "darkenBlendMode",
            "lightenBlendMode",
            "colorDodgeBlendMode",
            "colorBurnBlendMode",
            "softLightBlendMode",
            "hardLightBlendMode",
            "differenceBlendMode",
            "exclusionBlendMode",
            "subtractBlendMode",
            "divideBlendMode",
            "linearBurnBlendMode",
            "linearDodgeBlendMode",
            "linearLightBlendMode",
            "pinLightBlendMode"
        ]

        for mode in blendModes {
            let item = NSMenuItem(title: mode, action: #selector(changeBackgroundBlendMode), keyEquivalent: "")
            item.target = self
            debugMenu.addItem(item)
        }
    }

    @objc private func changeBackgroundBlendMode(_ sender: NSMenuItem) {
        backgroundLayer.compositingFilter = sender.title
    }

    override func rightMouseDown(with event: NSEvent) {
        guard Self.enableDebugMenu else {
            super.rightMouseDown(with: event)
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        debugMenu.popUp(positioning: nil, at: location, in: self)
    }
    #endif
}
