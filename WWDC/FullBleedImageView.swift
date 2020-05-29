//
//  FullBleedImageView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class FullBleedImageView: NSView {

    var image: NSImage? {
        didSet {
            guard image != oldValue else { return }

            imageLayer.contents = image
            needsLayout = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private lazy var imageLayer: CALayer = {
        let l = CALayer()

        return l
    }()

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(imageLayer)
        imageLayer.contentsGravity = .resizeAspectFill
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()

        guard let image = image else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)

        let widthFactor = bounds.width / image.size.width

        let imageLayerWidth = image.size.width * widthFactor
        let imageLayerHeight = image.size.height * widthFactor

        imageLayer.frame = CGRect(x: 0, y: 0, width: imageLayerWidth, height: imageLayerHeight)

        CATransaction.commit()
    }
    
}
