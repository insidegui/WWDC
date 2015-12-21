//
//  AboutWindowController.swift
//  About
//
//  Created by Guilherme Rambo on 20/12/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class AboutWindowController: NSWindowController {

    @IBOutlet weak private var applicationNameLabel: NSTextField!
    @IBOutlet weak private var versionLabel: NSTextField!
    @IBOutlet weak var contributorsLabel: NSTextField!
    @IBOutlet weak private var creatorLabel: NSTextField!
    @IBOutlet weak private var licenseLabel: NSTextField!

    var infoText: String? {
        didSet {
            guard let infoText = infoText else { return }
            contributorsLabel.stringValue = infoText
        }
    }
    
    convenience init(infoText: String?) {
        self.init(windowNibName: "AboutWindowController")
        self.infoText = infoText
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        // close the window when the escape key is pressed
        NSEvent.addLocalMonitorForEventsMatchingMask(.KeyDownMask) { event in
            guard event.keyCode == 53 else { return event }
            
            self.closeAnimated()
            
            return nil
        }
        
        window?.collectionBehavior = [.Transient, .IgnoresCycle]
        window?.movable = false
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .Hidden
        
        let info = NSBundle.mainBundle().infoDictionary!
        
        if let appName = info["CFBundleName"] as? String {
            applicationNameLabel.stringValue = appName
        } else {
            applicationNameLabel.stringValue = ""
        }
        
        if let version = info["CFBundleShortVersionString"] as? String {
            versionLabel.stringValue = "Version \(version)"
        } else {
            versionLabel.stringValue = ""
        }
        
        if let infoText = infoText {
            contributorsLabel.stringValue = infoText
        } else {
            contributorsLabel.stringValue = ""
        }
        
        if let license = info["GRBundleLicenseName"] as? String {
            licenseLabel.stringValue = "License: \(license)"
        } else {
            licenseLabel.stringValue = ""
        }
        
        if let creator = info["GRBundleMainDeveloperName"] as? String {
            creatorLabel.stringValue = "Created by \(creator)"
        } else {
            creatorLabel.stringValue = ""
        }
    }
    
    override func showWindow(sender: AnyObject?) {
        window?.center()
        window?.alphaValue = 0.0
        
        super.showWindow(sender)
        
        window?.animator().alphaValue = 1.0
    }
    
    func closeAnimated() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.currentContext().duration = 0.4
        NSAnimationContext.currentContext().completionHandler = {
            self.close()
        }
        window?.animator().alphaValue = 0.0
        NSAnimationContext.endGrouping()
    }
    
}
