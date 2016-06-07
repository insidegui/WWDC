//
//  AppDelegate.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Crashlytics
import Sparkle

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
        NSUserDefaults.standardUserDefaults().registerDefaults(["NSApplicationCrashOnExceptions": true])
        
        // prefetch info for the about window
        About.sharedInstance.load()
        
        // start checking for live event
        LiveEventObserver.SharedObserver().start()
        
        // Keep a reference to the main application window
        window = NSApplication.sharedApplication().windows.last 
        
        // continue any paused downloads
        VideoStore.SharedStore().initialize()
        
        // initialize Crashlytics
        GRCrashlyticsHelper.install()
        
        // tell user about nice new things
        showCourtesyDialogs()
    }
    
    func applicationWillFinishLaunching(notification: NSNotification) {
        // register custom URL scheme handler
        URLSchemeHandler.SharedHandler().register()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    @IBAction func checkForUpdates(sender: AnyObject?) {
        SUUpdater.sharedUpdater().checkForUpdates(sender)
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
    
    // MARK: - Courtesy Dialogs
    
    private func showCourtesyDialogs() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(WWDCWeekDidStart), name: WWDCWeekDidStartNotification, object: nil)
        
        NewWWDCGreeter().presentAutomaticRefreshSuggestionIfAppropriate()
    }
    
    @objc private func WWDCWeekDidStart() {
        NewWWDCGreeter().presentAutomaticRefreshSuggestionIfAppropriate()
    }
    
    // MARK: - About Panel
    
    private lazy var aboutWindowController: AboutWindowController = {
        var aboutWC = AboutWindowController(infoText: About.sharedInstance.infoText)
        
        About.sharedInstance.infoTextChangedCallback = { newText in
            self.aboutWindowController.infoText = newText
        }
        
        return aboutWC
    }()
    
    @IBAction func showAboutWindow(sender: AnyObject?) {
        aboutWindowController.showWindow(sender)
    }

}

