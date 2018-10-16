//
//  NSImage+Thumbnail.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSImage {

    static func thumbnailImage(with url: URL, maxWidth: CGFloat) -> NSImage? {
        guard let inputImage = NSImage(contentsOf: url) else { return nil }

        let aspectRatio = inputImage.size.width / inputImage.size.height

        let thumbSize = NSSize(width: maxWidth, height: maxWidth * aspectRatio)

        let outputImage = NSImage(size: thumbSize)

        outputImage.lockFocus()

        inputImage.draw(in: NSRect(x: 0, y: 0, width: thumbSize.width, height: thumbSize.height), from: .zero, operation: .sourceOver, fraction: 1)

        outputImage.unlockFocus()

        return outputImage
    }

}

extension NSImage {

    func makeFreestandingTemplate(outputSize: NSSize) -> NSImage {
        let insetPercentage: CGFloat = 0.25
        var insetSize = outputSize
        let widthInset = outputSize.width * insetPercentage
        let heightInset = outputSize.height * insetPercentage
        insetSize.width -= 2 * widthInset
        insetSize.height -= 2 * heightInset

        let destinationRect = NSRect(origin: CGPoint(x: widthInset, y: heightInset), size: insetSize)

        // Circle Template
        let circle = CAShapeLayer()
        circle.path = CGPath(ellipseIn: CGRect(origin: .zero, size: outputSize), transform: nil)

        // New image
        let newImage = NSImage(size: outputSize)
        newImage.lockFocus()

        // Render both into new image
        let ctx = NSGraphicsContext.current!.cgContext
        circle.render(in: ctx)
        draw(in: destinationRect, from: .zero, operation: .xor, fraction: 1)

        newImage.unlockFocus()

        newImage.isTemplate = true

        return newImage
    }
}
