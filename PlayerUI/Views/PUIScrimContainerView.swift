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

        layer?.addSublayer(bottomScrimLayer)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private let scrimRatio: CGFloat = 0.18

    private let scrimOpacity: Float = 0.5

    private let scrimColor = NSColor.black

    private lazy var scrimColors: [CGColor] = [
        scrimColor.withAlphaComponent(1).cgColor,
        scrimColor.withAlphaComponent(0.95).cgColor,
        scrimColor.withAlphaComponent(0.8).cgColor,
        scrimColor.withAlphaComponent(0.5).cgColor,
        scrimColor.withAlphaComponent(0.2).cgColor,
        scrimColor.withAlphaComponent(0.05).cgColor,
        scrimColor.withAlphaComponent(0).cgColor
    ]

    private let scrimLocations: [NSNumber] = [
        NSNumber(value: 0),
        NSNumber(value: 0.037),
        NSNumber(value: 0.1),
        NSNumber(value: 0.3),
        NSNumber(value: 0.5),
        NSNumber(value: 0.7),
        NSNumber(value: 1)
    ]

    private lazy var bottomScrimLayer: PUIBoringGradientLayer = {
        let l = PUIBoringGradientLayer()

        l.colors = self.scrimColors
        l.locations = self.scrimLocations
        l.startPoint = CGPoint(x: 0, y: 0)
        l.endPoint = CGPoint(x: 0, y: 1)
        l.opacity = self.scrimOpacity

        return l
    }()

    override func layout() {
        var topRect = bounds
        topRect.size.height = bounds.height * 0.3
        bottomScrimLayer.frame = topRect
    }

}
