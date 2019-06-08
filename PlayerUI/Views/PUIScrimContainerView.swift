//
//  PUIScrimContainerView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PUIScrimContainerView: NSView {

    var isScrimEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "PUIScrimEnabled")
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

        if isScrimEnabled {
            layer?.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.2).cgColor

            layer?.addSublayer(topScrimLayer)
        }

        layer?.addSublayer(bottomScrimLayer)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private let scrimRatio: CGFloat = 0.138

    private let scrimOpacity: Float = 0.4

    private let scrimColors: [CGColor] = [
        NSColor(calibratedWhite: 0, alpha: 1).cgColor,
        NSColor(calibratedWhite: 0, alpha: 0.88).cgColor,
        NSColor(calibratedWhite: 0, alpha: 0.75).cgColor,
        NSColor(calibratedWhite: 0, alpha: 0.5).cgColor,
        NSColor(calibratedWhite: 0, alpha: 0.25).cgColor,
        NSColor(calibratedWhite: 0, alpha: 0.12).cgColor,
        NSColor(calibratedWhite: 0, alpha: 0).cgColor
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

    private lazy var topScrimLayer: PUIBoringGradientLayer = {
        let l = PUIBoringGradientLayer()

        l.colors = self.scrimColors
        l.locations = self.scrimLocations
        l.startPoint = CGPoint(x: 0, y: 1)
        l.endPoint = CGPoint(x: 0, y: 0)
        l.opacity = self.scrimOpacity

        return l
    }()

    override func layout() {
        var topRect = bounds
        topRect.size.height = bounds.height * scrimRatio
        bottomScrimLayer.frame = topRect

        var bottomRect = bounds
        bottomRect.size.height = bounds.height * scrimRatio
        bottomRect.origin.y = bounds.height - bottomRect.height
        topScrimLayer.frame = bottomRect
    }

}
