//
//  MainWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        configureWindowAppearance()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSWindowWillClose, object: window, queue: nil) { _ in
            if let window = self.window {
                Preferences.SharedPreferences().mainWindowFrame = window.frame
            }
        }
    }
    
    override func showWindow(_ sender: Any?) {
        restoreWindowSize()
        
        super.showWindow(sender)
    }
    
    fileprivate func configureWindowAppearance()
    {
        if let window = window {
            if let view = window.contentView {
                view.wantsLayer = true
            }
            
            window.styleMask |= NSFullSizeContentViewWindowMask
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
    }
    
    fileprivate func restoreWindowSize()
    {
        if let window = window {
            var savedFrame = Preferences.SharedPreferences().mainWindowFrame
            
            if savedFrame != NSZeroRect {
                if let screen = NSScreen.main() {
                    // if the screen's height changed between launches, the window can be too big
                    if savedFrame.size.height > screen.frame.size.height {
                        savedFrame.size.height = screen.frame.size.height
                    }
                }
                
                window.setFrame(savedFrame, display: true)
            }
        }
    }
    
    @IBAction func toggleSidebar(_ sender: AnyObject) {
        guard let splitController = window?.contentViewController as? NSSplitViewController, splitController.splitViewItems.count > 0 else { return }
        
        let sidebar = splitController.splitViewItems[0]
        
        sidebar.animator().isCollapsed = !sidebar.isCollapsed
    }

}
