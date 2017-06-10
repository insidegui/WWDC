//
//  NSEvent+ForceTouch.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

enum PUITouchForce: Int {
    case reserved = -1
    case none = 0
    case normal = 1
    case forceTouch = 2
    case reserved2 = 3
}

extension NSEvent {

    var touchForce: PUITouchForce {
        return PUITouchForce(rawValue: synthesizedStage)!
    }

    private var synthesizedStage: Int {
        switch type {
        case .tabletPoint:
            if pressure > 0.5 {
                return 2
            } else {
                return 1
            }
        case .pressure:
            return stage
        default:
            return 1
        }
    }

}
