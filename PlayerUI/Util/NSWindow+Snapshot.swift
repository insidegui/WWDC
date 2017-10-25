//
//  NSWindow+Snapshot.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSWindow {

    var snapshot: NSImage? {
        guard windowNumber != -1 else { return nil }

        guard let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(windowNumber), .boundsIgnoreFraming) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: frame.size)

        image.cacheMode = .never

        return image
    }

    func snapshot(in rect: NSRect) -> NSImage? {
        guard let fullImage = snapshot else { return nil }

        let croppedImage = NSImage(size: rect.size)
        croppedImage.cacheMode = .never

        croppedImage.lockFocus()
        fullImage.draw(in: NSRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height), from: rect, operation: .sourceOver, fraction: 1)
        croppedImage.unlockFocus()

        return croppedImage
    }
}
