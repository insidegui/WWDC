//
//  AppDelegate.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Crashlytics
import Updater

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow?
	
    func applicationOpenUntitledFile(sender: NSApplication) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return false
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // check for updates
        checkForUpdates(nil)
        
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
	
    @IBAction func checkForUpdates(sender: AnyObject?) {
        UDUpdater.sharedUpdater().updateAutomatically = true
        UDUpdater.sharedUpdater().checkForUpdatesWithCompletionHandler { newRelease in
            if newRelease != nil {
                if sender != nil {
                    let alert = NSAlert()
                    alert.messageText = "New version available"
                    alert.informativeText = "Version \(newRelease.version) is now available. It will be installed automatically the next time you launch the app."
                    alert.addButtonWithTitle("Ok")
                    alert.runModal()
                } else {
                    let notification = NSUserNotification()
                    notification.title = "New version available"
                    notification.informativeText = "A new version is available, relaunch the app to update"
                    NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notification)
                }
            } else {
                if sender != nil {
                    let alert = NSAlert()
                    alert.messageText = "You're up to date!"
                    alert.informativeText = "You have the newest version"
                    alert.addButtonWithTitle("Ok")
                    alert.runModal()
                }
            }
        }
    }

}

