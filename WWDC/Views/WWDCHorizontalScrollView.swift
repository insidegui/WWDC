//
//  WWDCHorizontalScrollView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCHorizontalScrollView: NSScrollView {

    private var isScrollingHorizontally = false

    override func scrollWheel(with event: NSEvent) {
        if event.phase == .mayBegin {
            super.scrollWheel(with: event)
            nextResponder?.scrollWheel(with: event)
            return
        }

        if event.phase == .began || (event.phase == .none && event.momentumPhase == .none) {
            isScrollingHorizontally = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        }

        if isScrollingHorizontally {
            super.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }

}

extension NSEvent.Phase {
    static let none: NSEvent.Phase = []
}
