//
//  PUIScrimContainerView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PUIScrimContainerView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

        layer?.addSublayer(lowerScrimLayer)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private let scrimOpacity: Float = 0.5

    // Think of the combination of scrim colors and scrim locations as defining a curve describing the fall-off of the gradient.

    private lazy var scrimColors: [CGColor] = [
        NSColor.scrimColor.withAlphaComponent(1).cgColor,
        NSColor.scrimColor.withAlphaComponent(0.9).cgColor,
        NSColor.scrimColor.withAlphaComponent(0.7).cgColor,
        NSColor.scrimColor.withAlphaComponent(0.5).cgColor,
        NSColor.scrimColor.withAlphaComponent(0).cgColor
    ]

    private let scrimLocations: [NSNumber] = [
        NSNumber(value: 0),
        NSNumber(value: 0.3),
        NSNumber(value: 0.5),
        NSNumber(value: 0.8),
        NSNumber(value: 1)
    ]

    private lazy var lowerScrimLayer: PUIBoringGradientLayer = {
        let l = PUIBoringGradientLayer()

        l.colors = self.scrimColors
        l.locations = self.scrimLocations
        l.startPoint = CGPoint(x: 0, y: 0)
        l.endPoint = CGPoint(x: 0, y: 1)
        l.opacity = self.scrimOpacity

        return l
    }()

    override func layout() {
        lowerScrimLayer.frame = bounds
    }

}
