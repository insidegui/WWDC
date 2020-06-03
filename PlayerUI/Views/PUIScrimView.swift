//
//  PUIScrimContainerView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PUIScrimView: NSView {

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

        addSubview(vfxView)
        vfxView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        vfxView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        vfxView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        vfxView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
