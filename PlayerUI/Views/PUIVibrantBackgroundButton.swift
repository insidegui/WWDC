//
//  PUIVibrantBackgroundButton.swift
//  PlayerUI
//
//  Created by Allen Humphreys on 6/8/19.
//  Copyright © 2019 Guilherme Rambo. All rights reserved.
//

import Foundation

class PUIVibrantButton: NSView {

    private lazy var vfxView: NSVisualEffectView = {
        let v = NSVisualEffectView(frame: .zero)

        v.translatesAutoresizingMaskIntoConstraints = false
        v.blendingMode = .withinWindow
        v.material = .dark
        v.appearance = NSAppearance(named: .vibrantDark)
        v.state = .active

        return v
    }()

    lazy var button: PUIButton = {
        let v = PUIButton(frame: .zero)

        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = 10

        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        addSubview(vfxView)

        vfxView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        vfxView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        vfxView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        vfxView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        vfxView.addSubview(button)
        vfxView.heightAnchor.constraint(equalTo: button.heightAnchor, multiplier: 1, constant: 20).isActive = true
        vfxView.widthAnchor.constraint(equalTo: button.widthAnchor, multiplier: 1, constant: 20).isActive = true
        button.centerXAnchor.constraint(equalTo: vfxView.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: vfxView.centerYAnchor).isActive = true
    }
}
