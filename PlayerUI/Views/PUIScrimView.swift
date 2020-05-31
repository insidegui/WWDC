//
//  PUIScrimContainerView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PUIScrimView: NSView {

    private let scrimOpacity: Float = 0.75
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
    private lazy var scrimLayer: PUIBoringGradientLayer = {
        let l = PUIBoringGradientLayer()

        l.colors = self.scrimColors
        l.locations = self.scrimLocations
        l.startPoint = CGPoint(x: 0, y: 0)
        l.endPoint = CGPoint(x: 0, y: 1)
        l.opacity = self.scrimOpacity

        return l
    }()

    private lazy var vfxView: NSVisualEffectView = {
        let v = NSVisualEffectView(frame: .zero)

        v.translatesAutoresizingMaskIntoConstraints = false
        v.blendingMode = .withinWindow
        v.material = .menu
        v.appearance = NSAppearance(named: .vibrantDark)
        v.state = .active

        return v
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

//        layer?.addSublayer(lowerScrimLayer)
        addSubview(vfxView)
        vfxView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        vfxView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        vfxView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        vfxView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

//    override func layout() {
////        lowerScrimLayer.frame = bounds
//    }

}
