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
        
        NSNotificationCenter.defaultCenter().addObserverForName(NSWindowWillCloseNotification, object: nil, queue: nil) { _ in
            if let window = self.window {
                Preferences.SharedPreferences().mainWindowFrame = window.frame
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(LiveEventNextInfoChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { _ in
            if let liveBanner = LiveEventBannerViewController.DefaultController {
                liveBanner.event = LiveEventObserver.SharedObserver().nextEvent
                if let window = self.window {
                    window.contentView!.addSubview(liveBanner.view)
                    liveBanner.prepareForParentView(window.contentView!)
                }
            }
        }
    }
    
    override func showWindow(sender: AnyObject?) {
        restoreWindowSize()
        
        super.showWindow(sender)
    }
    
    private func configureWindowAppearance()
    {
        if let window = window {
            if let view = window.contentView {
                view.wantsLayer = true
            }
            
            window.styleMask |= NSFullSizeContentViewWindowMask
            window.titleVisibility = .Hidden
            window.titlebarAppearsTransparent = true
        }
    }
    
    private func restoreWindowSize()
    {
        if let window = window {
            var savedFrame = Preferences.SharedPreferences().mainWindowFrame
            
            if savedFrame != NSZeroRect {
                if let screen = NSScreen.mainScreen() {
                    // if the screen's height changed between launches, the window can be too big
                    if savedFrame.size.height > screen.frame.size.height {
                        savedFrame.size.height = screen.frame.size.height
                    }
                }
                
                window.setFrame(savedFrame, display: true)
            }
        }
    }

}
