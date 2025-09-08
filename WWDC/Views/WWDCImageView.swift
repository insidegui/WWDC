//
//  WWDCImageView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class WWDCImageView: NSView {

    var cornerRadius: CGFloat = 4 {
        didSet {
            guard cornerRadius != oldValue else { return }

            updateCorners()
        }
    }

    var drawsBackground = true {
        didSet {
            backgroundLayer.isHidden = !drawsBackground
        }
    }

    override var isOpaque: Bool { drawsBackground && cornerRadius.isZero }

    var backgroundColor: NSColor = .clear {
        didSet {
            backgroundLayer.backgroundColor = backgroundColor.cgColor
        }
    }

    var image: NSImage? {
        didSet {
            imageLayer.contents = image
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var backgroundLayer: WWDCLayer = {
        let l = WWDCLayer()

        l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        return l
    }()

    private(set) lazy var imageLayer: WWDCLayer = {
        let l = WWDCLayer()

        l.contentsGravity = .resizeAspect
        l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        l.zPosition = 1

        return l
    }()

    private func buildUI() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous

        backgroundLayer.frame = bounds
        imageLayer.frame = bounds

        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(imageLayer)

        updateCorners()
    }

    override func makeBackingLayer() -> CALayer {
        return WWDCLayer()
    }

    private func updateCorners() {
        layer?.cornerRadius = cornerRadius
    }

}
