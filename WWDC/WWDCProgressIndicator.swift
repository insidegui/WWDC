//
//  WWDCProgressIndicator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 24/10/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class WWDCProgressIndicator: NSView {

    private struct Metrics {
        static let defaultSize: CGFloat = 32
        static let lineWidth: CGFloat = 2
        static let apparentProgressWhenIndeterminate: Float = 0.9

        struct Animation {
            static let indeterminateDuration: TimeInterval = 1
            static let updateDuration: TimeInterval = 0.4
        }
    }

    var fillColor: NSColor { .primary }

    var isIndeterminate = false {
        didSet {
            guard isIndeterminate != oldValue else { return }

            progressBackgroundLayer.opacity = isIndeterminate ? 0 : 1
            apparentProgress = isIndeterminate ? Metrics.apparentProgressWhenIndeterminate : progress

            if isIndeterminate {
                performIndeterminateAnimation()
            } else {
                stopPerformingIndeterminateAnimation()
            }
        }
    }

    private(set) var isAnimating = false

    private var apparentProgress: Float = 0 {
        didSet {
            guard apparentProgress != oldValue else { return }

            updateProgress()
        }
    }

    var progress: Float = 0 {
        didSet {
            guard !isIndeterminate else { return }

            apparentProgress = progress
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        setup()
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: Metrics.defaultSize, height: Metrics.defaultSize)
    }

    override func layout() {
        super.layout()

        layoutProgressLayer()
    }

    func startAnimating() {
        isAnimating = true
    }

    func stopAnimating() {
        isAnimating = false
    }

    private lazy var containerLayer = CALayer()

    private lazy var progressBackgroundLayer: CAShapeLayer = {
        let l = CAShapeLayer()

        l.lineWidth = Metrics.lineWidth
        l.fillColor = nil

        return l
    }()

    private lazy var progressLayer: CAShapeLayer = {
        let l = CAShapeLayer()

        l.lineWidth = Metrics.lineWidth
        l.fillColor = nil
        l.strokeEnd = 0
        l.transform = CATransform3DMakeScale(-1, 1, 1)
        l.transform = CATransform3DRotate(l.transform, 90*CGFloat.pi/180, 0, 0, 1)

        return l
    }()

    private func setup() {
        wantsLayer = true
        layer = CALayer()

        layer?.addSublayer(progressBackgroundLayer)

        layer?.addSublayer(containerLayer)
        containerLayer.addSublayer(progressLayer)

        layoutProgressLayer()
        updateColor()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateColor),
                                               name: NSColor.systemColorsDidChangeNotification,
                                               object: nil)
    }

    private func makeProgressCircle() -> CGPath {
        let pathRect = bounds.insetBy(dx: Metrics.lineWidth, dy: Metrics.lineWidth)

        return CGPath(ellipseIn: pathRect, transform: nil)
    }

    private func layoutProgressLayer() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        CATransaction.setDisableActions(true)
        progressBackgroundLayer.frame = bounds
        containerLayer.frame = bounds
        progressLayer.frame = bounds
        progressBackgroundLayer.path = makeProgressCircle()
        progressLayer.path = makeProgressCircle()
        CATransaction.commit()
    }

    @objc private func updateColor() {
        progressLayer.strokeColor = fillColor.cgColor
        progressBackgroundLayer.strokeColor = fillColor.withAlphaComponent(0.35).cgColor
    }

    private func updateProgress() {
        let duration: TimeInterval = isAnimating ? Metrics.Animation.updateDuration : 0

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setDisableActions(!isAnimating)

        progressLayer.strokeEnd = CGFloat(apparentProgress)

        CATransaction.commit()
    }

    private lazy var indeterminateAnimation: CABasicAnimation = {
        let a = CABasicAnimation(keyPath: "transform.rotation.z")

        a.fromValue = CGFloat(0)
        a.byValue = -CGFloat.pi
        a.toValue = -360 * CGFloat.pi/180
        a.isAdditive = true
        a.isRemovedOnCompletion = false
        a.fillMode = .forwards
        a.duration = 1
        a.repeatCount = .infinity

        return a
    }()

    private let indeterminateAnimationKey = "indeterminate"

    private func performIndeterminateAnimation() {
        containerLayer.add(indeterminateAnimation, forKey: indeterminateAnimationKey)
    }

    private func stopPerformingIndeterminateAnimation() {
        containerLayer.removeAnimation(forKey: indeterminateAnimationKey)
    }

}
