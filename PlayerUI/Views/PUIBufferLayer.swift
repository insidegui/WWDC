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

    var hashValue: Int {
        return "\(start)->\(duration)".hashValue
    }

    static func ==(lhs: PUIBufferSegment, rhs: PUIBufferSegment) -> Bool {
        return lhs.start == rhs.start && lhs.duration == rhs.duration
    }
}

final class PUIBufferLayer: CALayer {

    var segments = Set<PUIBufferSegment>() {
        didSet {
            needsDisplayOnBoundsChange = true

            setNeedsDisplay()
        }
    }

    override func draw(in ctx: CGContext) {
        ctx.setFillColor(NSColor.playerBuffer.cgColor)

        let cr = PUITimelineView.Metrics.cornerRadius

        segments.forEach { segment in
            let rect = self.rect(for: segment)

            guard rect.width > 0 && rect.height > 0 else { return }
            guard rect.width >= cr * 2 else { return }

            let path = CGPath(roundedRect: rect, cornerWidth: cr, cornerHeight: cr, transform: nil)
            ctx.addPath(path)

            ctx.fillPath()
        }
    }

    private func rect(for segment: PUIBufferSegment) -> CGRect {
        let cr = PUITimelineView.Metrics.cornerRadius

        let x: CGFloat = round(bounds.width * CGFloat(segment.start) - cr)
        let w: CGFloat = round(bounds.width * CGFloat(segment.duration) + cr)

        return CGRect(x: x, y: 0, width: w, height: bounds.height)
    }

}
