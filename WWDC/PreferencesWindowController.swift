//
//  PreferencesWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController {
    
    let prefs = Preferences.SharedPreferences()
    private var downloadStartedHndl: AnyObject?
    private var downloadFinishedHndl: AnyObject?
    private var downloadChangedHndl: AnyObject?
    private var downloadCancelledHndl: AnyObject?
    private var downloadPausedHndl: AnyObject?
    private var downloadResumedHndl: AnyObject?
    
    convenience init() {
        self.init(windowNibName: "PreferencesWindowController")
    }
    
    
    @IBOutlet weak var downloadProgressIndicator: NSProgressIndicator!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        populateFontsPopup()
        
        downloadsFolderLabel.stringValue = prefs.localVideoStoragePath
        
        automaticRefreshEnabledCheckbox.state = prefs.automaticRefreshEnabled ? NSOnState : NSOffState
        
        if let familyName = prefs.transcriptFont.familyName {
            fontPopUp.selectItemWithTitle(familyName)
        }
        
        let size = "\(Int(prefs.transcriptFont.pointSize))"
        sizePopUp.selectItemWithTitle(size)
        
        textColorWell.color = prefs.transcriptTextColor
        bgColorWell.color = prefs.transcriptBgColor
    }
    
    // MARK: Downloads folder
    
    @IBOutlet weak var downloadsFolderLabel: NSTextField!
    
    @IBAction func changeDownloadsFolder(sender: NSButton) {
        let panel = NSOpenPanel()
        panel.directoryURL = NSURL(fileURLWithPath: Preferences.SharedPreferences().localVideoStoragePath)
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.beginSheetModalForWindow(window!) { result in
            if result > 0 {
                if let path = panel.URL?.path {
                    Preferences.SharedPreferences().localVideoStoragePath = path
                    self.downloadsFolderLabel.stringValue = path
                }
            }
        }
    }
    
    @IBAction func doanloaAllButtonPressed(sender: AnyObject) {
        let nc = NSNotificationCenter.defaultCenter()
        

        
        let completionHandler: DataStore.fetchSessionsCompletionHandler = { success, sessions in
            dispatch_async(dispatch_get_main_queue()) {
                
                
                let sessions2015 = sessions.filter{(session) in
                    return session.year == 2015
                }
                
                println("Videos fetched, start downloading")
                DownloadVideosBatch.SharedDownloader().sessions = sessions2015
                DownloadVideosBatch.SharedDownloader().startDownloading()
              }
        }
        
        DataStore.SharedStore.fetchSessions(completionHandler, disableCache: true)
        self.addNotifications()
        
        
        
        
    }
    
    
    @IBAction func revealInFinder(sender: NSButton) {
        let path = Preferences.SharedPreferences().localVideoStoragePath
        let root = path.stringByDeletingLastPathComponent
        NSWorkspace.sharedWorkspace().selectFile(path, inFileViewerRootedAtPath: root)
    }
    
    // MARK: Session refresh
    
    @IBOutlet weak var automaticRefreshEnabledCheckbox: NSButton!
    
    @IBAction func automaticRefreshCheckboxAction(sender: NSButton) {
        prefs.automaticRefreshEnabled = (sender.state == NSOnState)
    }
    
    // MARK: Transcript appearance
    
    @IBOutlet weak var fontPopUp: NSPopUpButton!
    @IBOutlet weak var sizePopUp: NSPopUpButton!
    @IBOutlet weak var textColorWell: NSColorWell!
    @IBOutlet weak var bgColorWell: NSColorWell!
    
    @IBAction func fontPopUpAction(sender: NSPopUpButton) {
        if let newFont = NSFont(name: fontPopUp.selectedItem!.title, size: prefs.transcriptFont.pointSize) {
            prefs.transcriptFont = newFont
        }
    }
    
    @IBAction func sizePopUpAction(sender: NSPopUpButton) {
        let size = NSString(string: sizePopUp.selectedItem!.title).doubleValue
        prefs.transcriptFont = NSFont(name: prefs.transcriptFont.fontName, size: CGFloat(size))!
    }
    
    @IBAction func textColorWellAction(sender: NSColorWell) {
        prefs.transcriptTextColor = textColorWell.color
    }
    
    @IBAction func bgColorWellAction(sender: NSColorWell) {
        prefs.transcriptBgColor = bgColorWell.color
    }
    
    func populateFontsPopup() {
        fontPopUp.addItemsWithTitles(NSFontManager.sharedFontManager().availableFontFamilies)
    }
    
    
    
    private func hideProgressIndicator() {
        self.downloadProgressIndicator.hidden = true
        downloadProgressIndicator.stopAnimation(nil)

    }
    private func showProgressIndicator() {
        self.downloadProgressIndicator.hidden = false
        downloadProgressIndicator.startAnimation(nil)

    }
    
    private func addNotifications() {
        
        let nc = NSNotificationCenter.defaultCenter()
        
        self.downloadStartedHndl = nc.addObserverForName(VideoStoreNotificationDownloadProgressChanged, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            let url = note.object as! String?
            if url != nil {
                self.showProgressIndicator()
            }
        }
        self.downloadFinishedHndl = nc.addObserverForName(VideoStoreNotificationDownloadFinished, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            if let object = note.object as? String {
                let url = object as String
                
                self.hideProgressIndicator()
            }
        }
        self.downloadChangedHndl = nc.addObserverForName(VideoStoreNotificationDownloadProgressChanged, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            if let info = note.userInfo {
                if let object = note.object as? String {
                    let url = object as String
                    if let expected = info["totalBytesExpectedToWrite"] as? Int,
                        let written = info["totalBytesWritten"] as? Int
                    {
//                        let progress = Double(written) / Double(expected)
                        
                    }
                }
            }
        }
        self.downloadCancelledHndl = nc.addObserverForName(VideoStoreNotificationDownloadCancelled, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            if let object = note.object as? String {
                let url = object as String
                
                self.hideProgressIndicator()
            }
        }
        self.downloadPausedHndl = nc.addObserverForName(VideoStoreNotificationDownloadPaused, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            if let object = note.object as? String {
                let url = object as String
                
                self.hideProgressIndicator()
            }
        }
        self.downloadResumedHndl = nc.addObserverForName(VideoStoreNotificationDownloadResumed, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            if let object = note.object as? String {
                let url = object as String
                self.showProgressIndicator()
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadStartedHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadFinishedHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadChangedHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadCancelledHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadPausedHndl!)
        NSNotificationCenter.defaultCenter().removeObserver(self.downloadResumedHndl!)
    }

}
