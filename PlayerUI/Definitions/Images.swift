//
//  Images.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSImage {

    private static var playerBundle: Bundle {
        return Bundle(for: PUIButton.self)
    }

    static var PUIPlay: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "play"))!
    }

    static var PUIPause: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "pause"))!
    }

    static var PUIAirplay: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "airplay"))!
    }

    static var PUIBack15s: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "back15s"))!
    }

    static var PUIBack30s: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "back30s"))!
    }

    static var PUIAnnotation: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "bookmark"))!
    }

    static var PUIForward15s: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "forward15s"))!
    }

    static var PUIForward30s: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "forward30s"))!
    }

    static var PUIFullScreen: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "fullscreen"))!
    }

    static var PUINextAnnotation: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "nextbookmark"))!
    }

    static var PUIPreviousAnnotation: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "prevbookmark"))!
    }

    static var PUIPictureInPicture: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "pip"))!
    }

    static var PUIPictureInPictureLarge: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "pip-big"))!
    }

    static var PUISubtitles: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "subtitles"))!
    }

    static var PUIVolume: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "volume"))!
    }

    static var PUIVolumeMuted: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "nosound"))!
    }

    static var PUISpeedOne: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "speed-1"))!
    }

    static var PUISpeedHalf: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "speed-h"))!
    }

    static var PUISpeedOneAndFourth: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "speed-125"))!
    }

    static var PUISpeedOneAndHalf: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "speed-15"))!
    }

    static var PUISpeedTwo: NSImage {
        return playerBundle.image(forResource: NSImage.Name(rawValue: "speed-2"))!
    }

}

// MARK: - Touch Bar

extension NSImage {

    func touchBarImage(with scale: CGFloat) -> NSImage {
        let image = PUITouchBarImageCache.shared.touchBarImage(for: self, with: scale)

        image.isTemplate = true

        return image
    }

}

private final class PUITouchBarImageCache {

    static let shared = PUITouchBarImageCache()

    private var cachedImages: [NSImage.Name: NSImage] = [:]

    func touchBarImage(for inputImage: NSImage, with scale: CGFloat) -> NSImage {
        if let name = inputImage.name(), let cachedImage = cachedImages[name] { return cachedImage }

        let newSize = NSSize(width: round(inputImage.size.width * scale),
                             height: round(inputImage.size.height * scale))

        let outputImage = NSImage(size: newSize)
        outputImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        inputImage.draw(in: NSRect(origin: .zero, size: newSize))

        outputImage.unlockFocus()

        if let name = inputImage.name() {
            cachedImages[name] = outputImage
        }

        return outputImage
    }

}
