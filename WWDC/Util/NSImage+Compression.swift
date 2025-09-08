//
//  NSImage+Compression.swift
//  WWDC
//
//  Created by Guilherme Rambo on 24/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSImage {

    private func compressedJPEG(with factor: Double) -> Data? {
        guard let tiff = tiffRepresentation else { return nil }
        guard let imageRep = NSBitmapImageRep(data: tiff) else { return nil }

        let options: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: factor
        ]

        return imageRep.representation(using: .jpeg, properties: options)
    }

    var compressedJPEGRepresentation: Data? {
        return compressedJPEG(with: 0.35)
    }

}
