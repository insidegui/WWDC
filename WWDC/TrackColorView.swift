//
//  TrackColorView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class TrackColorView: NSView {

    private lazy var progressLayer: WWDCLayer = {
        let l = WWDCLayer()

        l.autoresizingMask = [.layerWidthSizable]

        return l
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = 2
        layer?.masksToBounds = true

        progressLayer.frame = bounds

        layer?.addSublayer(progressLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var hasValidProgress = false {
        didSet {
            needsLayout = true
        }
    }

    var progress: Double = 0.5 {
        didSet {
            // hide when fully watched
            alphaValue = progress >= Constants.watchedVideoRelativePosition ? 0 : 1

            if hasValidProgress && progress < 1 {
                layer?.borderWidth = 1
            } else {
                layer?.borderWidth = 0
            }

            needsLayout = true
        }
    }

    var color: NSColor = .black {
        didSet {
            layer?.borderColor = color.cgColor
            progressLayer.backgroundColor = color.cgColor
        }
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 4, height: -1)
    }

    override func layout() {
        super.layout()

        let progressHeight = hasValidProgress ? bounds.height * CGFloat(progress) : bounds.height

        guard !progressHeight.isNaN && !progressHeight.isInfinite else { return }

        let progressFrame = NSRect(x: 0, y: 0, width: bounds.width, height: progressHeight)
        progressLayer.frame = progressFrame
    }

    override func makeBackingLayer() -> CALayer {
        return WWDCLayer()
    }
}
