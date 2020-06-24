//
//  VectorButton.swift
//  WWDC
//
//  Created by Guilherme Rambo on 01/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VectorButton: NSControl {

    private lazy var assetLayer: CALayer = {
        CALayer.load(assetNamed: "share-vector")!
    }()

    private lazy var containerLayer: CALayer = {
        assetLayer.sublayer(named: "container", of: CALayer.self)!
    }()

    private lazy var shapeLayer: CAShapeLayer = {
        containerLayer.sublayer(named: "vector", of: CAShapeLayer.self)!
    }()

    var tintColor: NSColor = .controlAccentColor {
        didSet {
            guard tintColor != oldValue else { return }

            applyTint()
        }
    }

    private let assetName: String

    init(assetNamed name: String) {
        self.assetName = name

        super.init(frame: .zero)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private var shouldBeOpaque = false

    override var isOpaque: Bool { shouldBeOpaque }

    var backgroundColor: NSColor? {
        didSet {
            guard let color = backgroundColor else {
                layer?.backgroundColor = nil
                shouldBeOpaque = false
                return
            }

            layer?.backgroundColor = color.cgColor
            shouldBeOpaque = color.alphaComponent == 1
        }
    }

    private func setup() {
        wantsLayer = true

        layer?.addSublayer(containerLayer)
        applyTint()

        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)
    }

    @objc private func clicked() {
        guard let action = action, let target = target else { return }

        NSApp.sendAction(action, to: target, from: self)
    }

    private func applyTint() {
        shapeLayer.fillColor = tintColor.cgColor
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()

        layer?.resizeLayer(containerLayer)
    }

}
