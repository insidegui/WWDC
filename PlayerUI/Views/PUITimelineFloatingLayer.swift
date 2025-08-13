import SwiftUI

final class PUITimelineFloatingLayer: PUIBoringLayer, CAAnimationDelegate {

    var annotation: PUITimelineAnnotation? {
        didSet {
            attributedText = annotation.flatMap { PUITimelineFloatingLayer.attributedString(for: $0.timestamp, font: .monospacedDigitSystemFont(ofSize: PUITimelineView.Metrics.textSize, weight: .medium)) }
        }
    }

    var attributedText: NSAttributedString? {
        didSet {
            guard attributedText != oldValue else { return }

            updateSize()
            setNeedsLayout()
        }
    }

    var padding: CGSize = CGSize(width: 16, height: 10) {
        didSet {
            guard padding != oldValue else { return }

            updateSize()
            setNeedsLayout()
        }
    }

    func show(animated: Bool = true) {
        guard model().isHidden else { return }

        isHidden = false

        removeAllAnimations()

        guard animated else {
            transformLayer.sublayerTransform = CATransform3DIdentity
            transformLayer.opacity = 1
            return
        }

        let scaleAnim = CASpringAnimation.springFrom(CATransform3DMakeScale(0.2, 0.2, 1), to: CATransform3DIdentity, keyPath: "sublayerTransform")
        transformLayer.add(scaleAnim, forKey: "show")
        transformLayer.sublayerTransform = CATransform3DIdentity

        let fadeAnim = CABasicAnimation.basicFrom(0, to: 1, keyPath: "opacity", duration: 0.25)
        transformLayer.add(fadeAnim, forKey: "fadeIn")
        transformLayer.opacity = 1
    }

    func hide(animated: Bool = true) {
        guard !model().isHidden else { return }

        removeAllAnimations()

        guard animated else {
            transformLayer.sublayerTransform = CATransform3DMakeScale(0.2, 0.2, 1)
            transformLayer.opacity = 0
            return
        }

        let scaleAnim = CASpringAnimation.springFrom(CATransform3DIdentity, to: CATransform3DMakeScale(0.2, 0.2, 1), keyPath: "sublayerTransform", delegate: self)
        transformLayer.add(scaleAnim, forKey: "hide")
        transformLayer.sublayerTransform = CATransform3DMakeScale(0.2, 0.2, 1)
        
        let fadeAnim = CABasicAnimation.basicFrom(1, to: 0, keyPath: "opacity", duration: 0.25)
        transformLayer.add(fadeAnim, forKey: "fadeOut")
        transformLayer.opacity = 0
    }

    private struct AssetError: LocalizedError, CustomStringConvertible {
        var errorDescription: String?
        var description: String { errorDescription ?? "" }
        init(_ message: String) { self.errorDescription = message }
    }

    private lazy var backgroundLayer: CALayer = {
        CALayer.load(assetNamed: "TimeBubble", bundle: .playerUI) ?? CALayer()
    }()

    private lazy var textLayer: PUIBoringTextLayer = {
        let l = PUIBoringTextLayer()
        return l
    }()

    private lazy var transformLayer: CATransformLayer = {
        let l = CATransformLayer()
        return l
    }()

    private func updateSize() {
        guard let attributedText else { return }

        let textSize = attributedText.size()

        frame.size = CGSize(width: textSize.width + padding.width, height: textSize.height + padding.height)
    }

    override func layoutSublayers() {
        super.layoutSublayers()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        defer { CATransaction.commit() }

        guard let attributedText else {
            isHidden = true
            return
        }

        isHidden = false

        if backgroundLayer.superlayer == nil {
            transformLayer.addSublayer(backgroundLayer)
        }
        if textLayer.superlayer == nil {
            transformLayer.addSublayer(textLayer)
        }
        if transformLayer.superlayer == nil {
            addSublayer(transformLayer)
        }

        transformLayer.frame = bounds

        backgroundLayer.frame = bounds
        backgroundLayer.masksToBounds = true
        backgroundLayer.cornerCurve = .continuous
        backgroundLayer.cornerRadius = 12

        let textSize = attributedText.size()
        textLayer.string = attributedText
        textLayer.frame = CGRect(
            x: bounds.midX - textSize.width * 0.5,
            y: bounds.midY - textSize.height * 0.5,
            width: textSize.width,
            height: textSize.height
        )
        textLayer.contentsScale = NSApp.windows.first?.backingScaleFactor ?? 2
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        isHidden = true
    }

}

extension PUITimelineFloatingLayer {
    static func attributedString(for timestamp: Double, font: NSFont) -> NSAttributedString {
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center

        let timeTextAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: pStyle
        ]

        let timeStr = String(timestamp: timestamp) ?? ""

        return NSAttributedString(string: timeStr, attributes: timeTextAttributes)
    }
}

extension CABasicAnimation {
    static func basicFrom<V>(_ fromValue: V, to toValue: V, keyPath: String, duration: TimeInterval = 0.4, delegate: CAAnimationDelegate? = nil) -> Self {
        let anim = Self()
        anim.duration = duration
        anim.keyPath = keyPath
        anim.fromValue = fromValue
        anim.toValue = toValue
        anim.isRemovedOnCompletion = true
        anim.fillMode = .both
        anim.delegate = delegate
        return anim
    }
}

extension CASpringAnimation {
    static func springFrom<V>(
        _ fromValue: V,
        to toValue: V,
        keyPath: String,
        mass: CGFloat = 1,
        stiffness: CGFloat = 140,
        damping: CGFloat = 18,
        initialVelocity: CGFloat = 10,
        delegate: CAAnimationDelegate? = nil) -> CASpringAnimation
    {
        let anim = CASpringAnimation()
        anim.mass = mass
        anim.stiffness = stiffness
        anim.damping = damping
        anim.initialVelocity = initialVelocity
        anim.keyPath = keyPath
        anim.fromValue = fromValue
        anim.toValue = toValue
        anim.isRemovedOnCompletion = true
        anim.fillMode = .both
        anim.delegate = delegate
        return anim
    }
}

@Observable
class PUITimelineFloatingModel {
    var text: String?
    fileprivate var isHidden = true

    func setIsHidden(_ isHidden: Bool, animated: Bool = true) {
        guard animated else {
            self.isHidden = isHidden
            return
        }
        withAnimation(.bouncy) {
            self.isHidden = isHidden
        }
    }

    func show(animated: Bool = true) {
        setIsHidden(false, animated: animated)
    }

    func hide(animated: Bool = true) {
        setIsHidden(true, animated: animated)
    }
}

@available(macOS 26.0, *)
struct PUITimelineGlassFloatingView: View {
    @Environment(PUITimelineFloatingModel.self) var model
    var body: some View {
        Group {
            if !model.isHidden, let label = model.text {
                Text(label)
                    .font(.system(size: PUITimelineView.Metrics.floatingLayerTextSize))
                    .fontDesign(.monospaced)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .fixedSize()
                    .padding(.vertical, PUITimelineView.Metrics.floatingLayerMargin)
                    .padding(.horizontal, PUITimelineView.Metrics.floatingLayerMargin)
                    .glassEffect(.clear, in: .capsule)
                    .tint(.black.opacity(0.3))
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

#if DEBUG
struct PUITimelineFloatingLayer_Previews: PreviewProvider {
    static var previews: some View {
        if #available(macOS 26.0, *) {
            PUITimelineGlassFloatingView()
        }
    }
}
#endif
