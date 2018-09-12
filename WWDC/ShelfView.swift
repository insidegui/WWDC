//
//  ShelfView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class ShelfView: NSView {

    var image: NSImage? {
        didSet {
            imageLayer.contents = image
        }
    }

    private var imageLayer: CALayer!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer = CALayer()

        imageLayer = CALayer()
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.autoresizingMask = [.layerHeightSizable, .layerWidthSizable]
        imageLayer.frame = bounds

        layer?.addSublayer(imageLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
