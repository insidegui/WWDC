//
//  SplitManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class SplitManager: NSObject, NSSplitViewDelegate {

    var splitView: NSSplitView {
        didSet {
            splitView.delegate = self
        }
    }
    
    init(splitView: NSSplitView) {
        self.splitView = splitView
    }
    
    func splitViewDidResizeSubviews(notification: NSNotification) {
        if let sideView = splitView.subviews[0] as? NSView {
            Preferences.SharedPreferences().sidebarWidth = sideView.frame.size.width
        }
    }
    
    func restoreSidebarWidth()
    {
        if let sideView = splitView.subviews[0] as? NSView {
            var rect = splitView.frame
            rect.size.width = Preferences.SharedPreferences().sidebarWidth
            
            sideView.frame = rect
        }
    }
    
}
