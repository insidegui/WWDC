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
    
    @IBAction func downloadAllSessions(sender: AnyObject) {
    
        
        let completionHandler: DataStore.fetchSessionsCompletionHandler = { success, sessions in
            dispatch_async(dispatch_get_main_queue()) {
                
                
                let sessions2015 = sessions.filter{(session) in
                    return session.year == 2015 && !VideoStore.SharedStore().hasVideo(session.hd_url!)
                }
                
                print("Videos fetched, start downloading")
                DownloadVideosBatch.SharedDownloader().sessions = sessions2015
                DownloadVideosBatch.SharedDownloader().startDownloading()
              }
        }
        
        DataStore.SharedStore.fetchSessions(completionHandler, disableCache: true)
        
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            appDelegate.showDownloadsWindow(appDelegate)
        }
        
        
    }
    
    
    @IBAction func revealInFinder(sender: NSButton) {
        let path = Preferences.SharedPreferences().localVideoStoragePath
        let root = (path as NSString).stringByDeletingLastPathComponent

        let fileManager = NSFileManager.defaultManager()
        if !fileManager.fileExistsAtPath(path) {
            do {
                try fileManager.createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
            } catch _ {
            }
        }

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
}
