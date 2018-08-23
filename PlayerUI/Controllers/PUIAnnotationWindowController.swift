//
//  PUIAnnotationWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PUIAnnotationWindowController: NSWindowController {

    private struct Metrics {
        static let defaultRect: NSRect = NSRect(x: 0, y: 0, width: 280, height: 56)
        static let cornerRadius: CGFloat = 4.0
    }

    init() {
        let window = PUIAnnotationWindow(contentRect: Metrics.defaultRect, styleMask: .borderless, backing: .buffered, defer: false)

        super.init(window: window)

        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = vfxView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var vfxView: NSVisualEffectView = {
        let v = NSVisualEffectView(frame: .zero)

        v.state = .active
        v.blendingMode = .behindWindow
        v.material = .dark
        v.appearance = NSAppearance(named: .vibrantDark)
        v.maskImage = self.maskImage(with: Metrics.cornerRadius)

        return v
    }()

    private func maskImage(with cornerRadius: CGFloat) -> NSImage {
        let edgeLength = 2.0 * cornerRadius + 1.0
        let size = NSSize(width: edgeLength, height: edgeLength)

        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.set()

            let bezierPath = NSBezierPath(roundedRect: rect,
                                          xRadius: cornerRadius,
                                          yRadius: cornerRadius)

            bezierPath.fill()

            return true
        }

        image.capInsets = NSEdgeInsets(top: cornerRadius,
                                     left: cornerRadius,
                                     bottom: cornerRadius,
                                     right: cornerRadius)
        image.resizingMode = .stretch

        return image
    }

}
