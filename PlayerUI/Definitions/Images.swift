//
//  Images.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSImage {

    private static let playerBundle = Bundle(for: PUIButton.self)

    static var PUIPlay: NSImage { .PUISystemSymbol(named: "play.fill", label: "Play") }

    static var PUIPause: NSImage { .PUISystemSymbol(named: "pause.fill", label: "Pause") }

    static var PUIBack15s: NSImage { .PUISystemSymbol(named: "gobackward.15", label: "Forward 15 Seconds") }

    static var PUIBack30s: NSImage { .PUISystemSymbol(named: "gobackward.30", label: "Forward 30 Seconds") }

    static var PUIAnnotation: NSImage { .PUISystemSymbol(named: "bookmark.fill", label: "Add Bookmark") }

    static var PUIForward15s: NSImage { .PUISystemSymbol(named: "goforward.15", label: "Forward 15 Seconds") }

    static var PUIForward30s: NSImage { .PUISystemSymbol(named: "goforward.30", label: "Forward 30 Seconds") }

    static var PUIFullScreen: NSImage { .PUISystemSymbol(named: "arrow.up.left.and.arrow.down.right", label: "Enter Full Screen") }

    static var PUIFullScreenExit: NSImage { .PUISystemSymbol(named: "arrow.down.right.and.arrow.up.left", label: "Exit Full Screen") }

    static var PUINextAnnotation: NSImage { .PUISystemSymbol(named: "forward.end.fill", label: "Next Bookmark") }

    static var PUIPreviousAnnotation: NSImage { .PUISystemSymbol(named: "backward.end.fill", label: "Previous Bookmark") }

    static var PUIPictureInPicture: NSImage { .PUISystemSymbol(named: "pip.enter", label: "Enter PiP") }

    static var PUIExitPictureInPicture: NSImage { .PUISystemSymbol(named: "pip.exit", label: "Exit PiP") }

    static var PUIPictureInPictureLarge: NSImage { .PUISystemSymbol(named: "pip.fill", label: "Picture In Picture") }

    static var PUISubtitles: NSImage { .PUISystemSymbol(named: "text.bubble.fill", label: "Subtitles") }

    static var PUIVolume: NSImage { .PUISystemSymbol(named: "speaker.wave.3.fill", label: "Toggle Mute") }

    static var PUIVolumeMuted: NSImage { .PUISystemSymbol(named: "speaker.slash.fill", label: "Toggle Mute") }

    static var PUIAirPlay: NSImage { .PUISystemSymbol(named: "airplayvideo", label: "AirPlay") }

    static var PUISpeedOne: NSImage {
        return playerBundle.image(forResource: "speed-1")!
    }

    static var PUISpeedHalf: NSImage {
        return playerBundle.image(forResource: "speed-h")!
    }

    static var PUISpeedOneAndFourth: NSImage {
        return playerBundle.image(forResource: "speed-125")!
    }

    static var PUISpeedOneAndHalf: NSImage {
        return playerBundle.image(forResource: "speed-15")!
    }

    static var PUISpeedOneAndThreeFourths: NSImage {
        return playerBundle.image(forResource: "speed-175")!
    }

    static var PUISpeedTwo: NSImage {
        return playerBundle.image(forResource: "speed-2")!
    }

    private static func PUISystemSymbol(named name: String, label: String?) -> NSImage {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: label) else {
            assertionFailure("Missing system symbol \"\(name)\"")
            return NSImage()
        }

        return image
    }
}

// MARK: - Metrics

struct PUIControlMetrics: Hashable {
    var symbolSize: CGFloat
    var controlSize: CGFloat

    static let medium = PUIControlMetrics(symbolSize: 16, controlSize: 26)
    static let large = PUIControlMetrics(symbolSize: 28, controlSize: 38)

    var symbolConfiguration: NSImage.SymbolConfiguration {
        NSImage.SymbolConfiguration(pointSize: PUIControlMetrics.medium.symbolSize, weight: .medium, scale: .medium)
    }
}

extension NSImage {
    func withPlayerMetrics(_ metrics: PUIControlMetrics?) -> NSImage {
        guard let metrics else { return self }

        guard let configured = withSymbolConfiguration(metrics.symbolConfiguration) else {
            assertionFailure("Failed to apply control metrics")
            return self
        }

        return configured
    }
}

private extension NSImage.SymbolConfiguration {
    static let PUIMedium = NSImage.SymbolConfiguration(pointSize: PUIControlMetrics.medium.symbolSize, weight: .medium, scale: .medium)
    static let PUILarge = NSImage.SymbolConfiguration(pointSize: PUIControlMetrics.large.symbolSize, weight: .medium, scale: .large)
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
