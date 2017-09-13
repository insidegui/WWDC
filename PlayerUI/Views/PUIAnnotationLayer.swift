//
//  PUIAnnotationLayer.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PUIAnnotationLayer: PUIBoringLayer {

    private var attachmentSpacing: CGFloat = 0
    private var attachmentAttribute: NSLayoutConstraint.Attribute = .notAnAttribute

    private(set) var attachedLayer: PUIBoringTextLayer = PUIBoringTextLayer()

    func attach(layer: PUIBoringTextLayer, attribute: NSLayoutConstraint.Attribute, spacing: CGFloat) {
        guard attribute == .top else {
            fatalError("Only .top is implemented for now")
        }

        attachmentSpacing = spacing
        attachmentAttribute = attribute

        addSublayer(layer)

        attachedLayer = layer

        layoutAttached(layer: layer)
    }

    private func layoutAttached(layer: PUIBoringTextLayer) {
        layer.layoutIfNeeded()

        var f = layer.frame

        if let textLayerContents = layer.string as? NSAttributedString {
            let s = textLayerContents.size()
            f.size.width = ceil(s.width)
            f.size.height = ceil(s.height)
        }

        let y: CGFloat = -f.height - attachmentSpacing
        let x: CGFloat = -f.width / 2 + bounds.width / 2

        f.origin.x = x
        f.origin.y = y

        layer.frame = f
    }

    override func layoutSublayers() {
        super.layoutSublayers()

        layoutAttached(layer: attachedLayer)
    }

}
