//
//  PUIAnnotationLayer.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import SwiftUI

final class PUIAnnotationLayer: PUIBoringLayer {

    typealias Metrics = PUITimelineView.Metrics

    var isHighlighted = false {
        didSet {
            updateHighlightedState()
        }
    }

    override init() {
        super.init()

        setup()
    }

    override init(layer: Any) {
        super.init(layer: layer)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setup() {
        glyphContainer.isGeometryFlipped = false

        addSublayer(glyphContainer)
        glyph.fillColor = NSColor.white.cgColor
        glyph.strokeColor = NSColor.white.cgColor
        glyph.shadowColor = NSColor.black.cgColor
        glyph.shadowRadius = 6
        glyph.shadowOffset = .zero
        glyph.shadowOpacity = 0.2
    }

    private lazy var glyphContainer: CALayer = {
        CALayer.load(assetNamed: "Annotation", bundle: .playerUI) ?? CALayer()
    }()

    private lazy var glyph: CAShapeLayer = {
        guard let shapeLayer = glyphContainer.sublayer(path: "container.scale.position.shape", of: CAShapeLayer.self) else {
            assertionFailure("Broken Annotation asset")
            return CAShapeLayer()
        }
        return shapeLayer
    }()

    private func updateHighlightedState() {
        if isHighlighted {
            glyph.fillColor = NSColor.playerHighlight.cgColor
            glyph.lineWidth = 1
            let s = Metrics.annotationMarkerHoverScale
            transform = CATransform3DMakeScale(s, s, s)
        } else {
            animate {
                glyph.fillColor = NSColor.white.cgColor
                glyph.lineWidth = 0
                transform = CATransform3DIdentity
                borderWidth = 0
            }
        }
    }

    override func layoutSublayers() {
        super.layoutSublayers()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        defer { CATransaction.commit() }

        resizeLayer(glyphContainer.sublayers?.first)
    }

}

#if DEBUG
struct PUIAnnotationLayer_Previews: PreviewProvider {
    static var previews: some View { PUIPlayerView_Previews.previews }
}
#endif
