//
//  SplitManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class SplitManager: NSObject, NSSplitViewDelegate {

    var splitView: NSSplitView

    var isSavingDividerPosition = false
    
    init(splitView: NSSplitView) {
        self.splitView = splitView
    }
    
    func startSavingDividerPosition()
    {
        isSavingDividerPosition = true
    }
    
    func splitView(splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if isSavingDividerPosition {
            Preferences.SharedPreferences().dividerPosition = proposedPosition
            
            return proposedPosition
        } else {
            return Preferences.SharedPreferences().dividerPosition
        }
    }
    
    func restoreDividerPosition()
    {
        splitView.setPosition(Preferences.SharedPreferences().dividerPosition, ofDividerAtIndex: 0)
    }
    
}
