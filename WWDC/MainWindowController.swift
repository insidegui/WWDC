//
//  MainWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController {

    private var downloadListWindowController: DownloadListWindowController?
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        if let view = window?.contentView as? NSView {
            view.wantsLayer = true
        }
        
        window?.styleMask |= NSFullSizeContentViewWindowMask
        window?.titleVisibility = .Hidden
        window?.titlebarAppearsTransparent = true
    }
    
    @IBAction func showDownloadsWindow(sender: AnyObject?) {
        if downloadListWindowController == nil {
            downloadListWindowController = DownloadListWindowController()
        }
        
        downloadListWindowController?.showWindow(self)
    }

}
