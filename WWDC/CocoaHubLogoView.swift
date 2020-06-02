//
//  CocoaHubLogoView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 01/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class CocoaHubLogoView: NSView {

    private lazy var imageView: NSImageView = {
        let v = NSImageView(image: NSImage(named: .init("CocoaHub-wordmark"))!)

        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 124).isActive = true
        v.heightAnchor.constraint(equalToConstant: 39).isActive = true

        return v
    }()

    private lazy var backgroundView: NSVisualEffectView = {
        let v = NSVisualEffectView()

        v.translatesAutoresizingMaskIntoConstraints = false
        v.material = .appearanceBased
        v.blendingMode = .withinWindow

        return v
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = 8

        addSubview(backgroundView)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
}
