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
        return playerBundle.image(forResource: "play")!
    }
    
    static var PUIPause: NSImage {
        return playerBundle.image(forResource: "pause")!
    }
    
    static var PUIAirplay: NSImage {
        return playerBundle.image(forResource: "airplay")!
    }
    
    static var PUIBack30s: NSImage {
        return playerBundle.image(forResource: "back30s")!
    }
    
    static var PUIBookmark: NSImage {
        return playerBundle.image(forResource: "bookmark")!
    }
    
    static var PUIForward30s: NSImage {
        return playerBundle.image(forResource: "forward30s")!
    }
    
    static var PUIFullScreen: NSImage {
        return playerBundle.image(forResource: "fullscreen")!
    }
    
    static var PUINextBookmark: NSImage {
        return playerBundle.image(forResource: "nextbookmark")!
    }
    
    static var PUIPreviousBookmark: NSImage {
        return playerBundle.image(forResource: "prevbookmark")!
    }
    
    static var PUIPictureInPicture: NSImage {
        return playerBundle.image(forResource: "pip")!
    }
    
    static var PUIPictureInPictureLarge: NSImage {
        return playerBundle.image(forResource: "pip-big")!
    }
    
    static var PUISubtitles: NSImage {
        return playerBundle.image(forResource: "subtitles")!
    }
    
    static var PUIVolume: NSImage {
        return playerBundle.image(forResource: "volume")!
    }
    
    static var PUIVolumeMuted: NSImage {
        return playerBundle.image(forResource: "nosound")!
    }
    
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
    
    static var PUISpeedTwo: NSImage {
        return playerBundle.image(forResource: "speed-2")!
    }
    
}
