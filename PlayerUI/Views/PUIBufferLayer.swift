//
//  PUIBufferLayer.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

struct PUIBufferSegment: Hashable {
    let start: Double
    let duration: Double
}

final class PUIBufferLayer: PUIBoringLayer {

    var segments = Set<PUIBufferSegment>() {
        didSet {
            needsDisplayOnBoundsChange = true

            setNeedsDisplay()
        }
    }

    override func draw(in ctx: CGContext) {
        ctx.setFillColor(NSColor.bufferProgress.cgColor)

        let radius = bounds.height * 0.5

        segments.forEach { segment in
            let rect = self.rect(for: segment)

            guard rect.width > 0 && rect.height > 0 else { return }
            guard rect.width >= radius * 2 else { return }

            let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            ctx.addPath(path)

            ctx.fillPath()
        }
    }

    private func rect(for segment: PUIBufferSegment) -> CGRect {
        let radius = bounds.height * 0.5

        let x: CGFloat = round(bounds.width * CGFloat(segment.start) - radius)
        let w: CGFloat = round(bounds.width * CGFloat(segment.duration) + radius)

        return CGRect(x: x, y: 0, width: w, height: bounds.height)
    }

}
