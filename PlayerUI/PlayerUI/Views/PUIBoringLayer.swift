//
//  PUIBoringLayer.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 28/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import QuartzCore
import AVFoundation

class PUIBoringLayer: CALayer {
    
    private var shouldAnimate: Bool = false
    
    override func action(forKey event: String) -> CAAction? {
        if shouldAnimate {
            return super.action(forKey: event)
        } else {
            return nil
        }
    }
    
    func animate(with block: () -> Void) {
        shouldAnimate = true
        block()
        shouldAnimate = false
    }
    
}

final class PUIBoringPlayerLayer: AVPlayerLayer {
    
    private var shouldAnimate: Bool = false
    
    override func action(forKey event: String) -> CAAction? {
        if shouldAnimate {
            return super.action(forKey: event)
        } else {
            return nil
        }
    }
    
    func animate(with block: () -> Void) {
        shouldAnimate = true
        block()
        shouldAnimate = false
    }
    
}


final class PUIBoringTextLayer: CATextLayer {
    
    private var shouldAnimate: Bool = false
    
    override func action(forKey event: String) -> CAAction? {
        if shouldAnimate {
            return super.action(forKey: event)
        } else {
            return nil
        }
    }
    
    func animate(with block: () -> Void) {
        shouldAnimate = true
        block()
        shouldAnimate = false
    }
    
}
