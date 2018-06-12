//
//  NSImage+Thumbnail.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSSize {
    var aspectRatio: CGFloat {
        return width / height
    }
}

extension NSRect {
    init(width: CGFloat, height: CGFloat) {
        self.init(x: 0, y: 0, width: width, height: height)
    }

    init(size: NSSize) {
        self.init(origin: .zero, size: size)
    }
}

extension NSImage {

    static func thumbnailImage(with url: URL, maxWidth: CGFloat) -> NSImage? {
        guard let inputImage = NSImage(contentsOf: url) else { return nil }

        let aspectRatio = inputImage.size.aspectRatio

        let thumbSize = NSSize(width: maxWidth, height: maxWidth * aspectRatio)

        let outputImage = NSImage(size: thumbSize)

        outputImage.lockFocus()

        inputImage.draw(in: NSRect(size: thumbSize), from: .zero, operation: .sourceOver, fraction: 1)

        outputImage.unlockFocus()

        return outputImage
    }

}
