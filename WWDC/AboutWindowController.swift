//
//  AboutWindowController.swift
//  About
//
//  Created by Guilherme Rambo on 20/12/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class AboutWindowController: NSWindowController {

    @IBOutlet weak fileprivate var applicationNameLabel: NSTextField!
    @IBOutlet weak fileprivate var versionLabel: NSTextField!
    @IBOutlet weak var contributorsLabel: NSTextField!
    @IBOutlet weak fileprivate var creatorLabel: NSTextField!
    @IBOutlet weak fileprivate var licenseLabel: NSTextField!

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
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53 else { return event }
            
            self.closeAnimated()
            
            return nil
        }
        
        window?.collectionBehavior = [.transient, .ignoresCycle]
        window?.isMovable = false
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        
        let info = Bundle.main.infoDictionary!
        
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
    
    override func showWindow(_ sender: Any?) {
        window?.center()
        window?.alphaValue = 0.0
        
        super.showWindow(sender)
        
        window?.animator().alphaValue = 1.0
    }
    
    func closeAnimated() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current().duration = 0.4
        NSAnimationContext.current().completionHandler = {
            self.close()
        }
        window?.animator().alphaValue = 0.0
        NSAnimationContext.endGrouping()
    }
    
}
