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
