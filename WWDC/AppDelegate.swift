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
	
    fileprivate var downloadListWindowController: DownloadListWindowController?
    fileprivate var preferencesWindowController: PreferencesWindowController?
    
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return false
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        
        // prefetch info for the about window
        About.sharedInstance.load()
        
        // start checking for live event
        LiveEventObserver.SharedObserver().start()
        
        // Keep a reference to the main application window
        window = NSApplication.shared().windows.last 
        
        // continue any paused downloads
        VideoStore.SharedStore().initialize()
        
        // initialize Crashlytics
        GRCrashlyticsHelper.install()
        
        // tell user about nice new things
        showCourtesyDialogs()
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // register custom URL scheme handler
        URLSchemeHandler.SharedHandler().register()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @IBAction func checkForUpdates(_ sender: AnyObject?) {
        SUUpdater.shared().checkForUpdates(sender)
    }
    
    @IBAction func showDownloadsWindow(_ sender: AnyObject?) {
        if downloadListWindowController == nil {
            downloadListWindowController = DownloadListWindowController()
        }
        
        downloadListWindowController?.showWindow(self)
    }
    
    @IBAction func showPreferencesWindow(_ sender: AnyObject?) {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        
        preferencesWindowController?.showWindow(self)
    }
    
    // MARK: - Courtesy Dialogs
    
    fileprivate func showCourtesyDialogs() {
        NotificationCenter.default.addObserver(self, selector: #selector(WWDCWeekDidStart), name: NSNotification.Name(rawValue: WWDCWeekDidStartNotification), object: nil)
        
        NewWWDCGreeter().presentAutomaticRefreshSuggestionIfAppropriate()
    }
    
    @objc fileprivate func WWDCWeekDidStart() {
        NewWWDCGreeter().presentAutomaticRefreshSuggestionIfAppropriate()
    }
    
    // MARK: - About Panel
    
    fileprivate lazy var aboutWindowController: AboutWindowController = {
        var aboutWC = AboutWindowController(infoText: About.sharedInstance.infoText)
        
        About.sharedInstance.infoTextChangedCallback = { newText in
            self.aboutWindowController.infoText = newText
        }
        
        return aboutWC
    }()
    
    @IBAction func showAboutWindow(_ sender: AnyObject?) {
        aboutWindowController.showWindow(sender)
    }

}

