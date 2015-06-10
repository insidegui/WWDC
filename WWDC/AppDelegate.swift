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
	
    private var downloadListWindowController: DownloadListWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    
    func applicationOpenUntitledFile(sender: NSApplication) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return false
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // start checking for live event
        LiveEventObserver.SharedObserver().start()
        
        // check for updates
        checkForUpdates(nil)
        
        // Keep a reference to the main application window
        window = NSApplication.sharedApplication().windows.last as! NSWindow?
        
        // continue any paused downloads
        VideoStore.SharedStore().initialize()
        
        // initialize Crashlytics
        GRCrashlyticsHelper.install()
        
        // tell the user he can watch the live keynote using the app, only once
        if !Preferences.SharedPreferences().userKnowsLiveEventThing {
            tellUserAboutTheLiveEventThing()
        }
    }
    
    func applicationWillFinishLaunching(notification: NSNotification) {
        // register custom URL scheme handler
        URLSchemeHandler.SharedHandler().register()
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
                    alert.messageText = NSLocalizedString("New version available", comment: "new version available")
                    alert.informativeText = NSString.localizedStringWithFormat(NSLocalizedString("Version %s is now available. It will be installed automatically the next time you launch the app.", comment: "new version available subtitle"), newRelease.version) as String

                  alert.addButtonWithTitle(NSLocalizedString("Ok", comment:"updater new version ok button"))
                    alert.runModal()
                } else {
                    let notification = NSUserNotification()
                    notification.title = NSLocalizedString("New version available", comment: "new version available")
                  notification.informativeText = NSLocalizedString("A new version is available, relaunch the app to update", comment: "updater notification information text")
                    NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notification)
                }
            } else {
                if sender != nil {
                    let alert = NSAlert()
                  alert.messageText = NSLocalizedString("You're up to date!", comment: "You're up to date!")
                  alert.informativeText = NSLocalizedString("You have the newest version", comment: "You have the newest version")
                    alert.addButtonWithTitle("Ok")
                    alert.runModal()
                }
            }
        }
    }
    
    @IBAction func showDownloadsWindow(sender: AnyObject?) {
        if downloadListWindowController == nil {
            downloadListWindowController = DownloadListWindowController()
        }
        
        downloadListWindowController?.showWindow(self)
    }
    
    @IBAction func showPreferencesWindow(sender: AnyObject?) {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        
        preferencesWindowController?.showWindow(self)
    }
    
    private func tellUserAboutTheLiveEventThing() {
        let alert = NSAlert()
      alert.messageText = NSLocalizedString("Did you know?", comment: "Did you know?")
      alert.informativeText = NSLocalizedString("You can watch live WWDC events using this app! Just open the app while the event is live and It will start playing automatically.", comment: "You can watch live WWDC events using this app! Just open the app while the event is live and It will start playing automatically.")
      alert.addButtonWithTitle(NSLocalizedString("Got It!", comment: "Got It!"))
      alert.runModal()
        
      Preferences.SharedPreferences().userKnowsLiveEventThing = true
    }

}

