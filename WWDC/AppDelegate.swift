//
//  AppDelegate.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Crashlytics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow?
	
    func applicationOpenUntitledFile(sender: NSApplication) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return false
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Keep a reference to the main application window
        window = NSApplication.sharedApplication().windows.last as! NSWindow?
        
        // continue any paused downloads
        VideoStore.SharedStore().initialize()
        
        // initialize Crashlytics
        GRCrashlyticsHelper.install()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
	

}

