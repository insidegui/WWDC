//
//  SplitManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

private extension NSSplitView {
    
    var currentDividerPosition: CGFloat {
        get {
            let dividerDelta = dividerThickness/2
            if let sideView = self.subviews[0] as? NSView {
                return CGFloat(round(sideView.frame.size.width+dividerDelta))
            } else {
                return 0.0
            }
        }
    }
    
}

class SplitManager: NSObject, NSSplitViewDelegate {

    var splitView: NSSplitView
    var didRestoreDividerPosition = false
    
    init(splitView: NSSplitView) {
        self.splitView = splitView
    }
    
    func splitViewDidResizeSubviews(notification: NSNotification) {
        if !didRestoreDividerPosition {
            return
        }
        
        Preferences.SharedPreferences().dividerPosition = splitView.currentDividerPosition
    }
    
    func restoreDividerPosition()
    {
        splitView.setPosition(Preferences.SharedPreferences().dividerPosition, ofDividerAtIndex: 0)
        
        didRestoreDividerPosition = true
    }
    
}
