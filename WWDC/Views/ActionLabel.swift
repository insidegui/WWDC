//
//  ActionLabel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class ActionLabel: NSTextField {

    private var cursorTrackingArea: NSTrackingArea!

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if cursorTrackingArea != nil {
            removeTrackingArea(cursorTrackingArea)
        }

        cursorTrackingArea = NSTrackingArea(rect: bounds,
                                            options: [.cursorUpdate, .inVisibleRect, .activeInActiveApp],
                                            owner: self,
                                            userInfo: nil)
        addTrackingArea(cursorTrackingArea)
    }

    override func cursorUpdate(with event: NSEvent) {
        if event.trackingArea == cursorTrackingArea {
            NSCursor.pointingHand.push()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let action = action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

}
