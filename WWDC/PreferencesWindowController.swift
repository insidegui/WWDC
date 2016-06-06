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
        
        setupTranscriptIndexingControls()
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
    
    // MARK: - Transcripts index
    
    @IBOutlet weak var reindexTranscriptsButton: NSButton!
    @IBOutlet weak var transcriptsIndexingProgressIndicator: NSProgressIndicator!
    
    private var installedIndexingObservers = false
    
    @objc private func setupTranscriptIndexingControls() {
        if !installedIndexingObservers {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(setupTranscriptIndexingControls), name: TranscriptIndexingDidStartNotification, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(setupTranscriptIndexingControls), name: TranscriptIndexingDidStopNotification, object: nil)
            
            installedIndexingObservers = true
        }
        
        if !WWDCDatabase.sharedDatabase.isIndexingTranscripts {
            reindexTranscriptsButton.enabled = true
            transcriptsIndexingProgressIndicator.stopAnimation(nil)
            transcriptsIndexingProgressIndicator.hidden = true
        } else {
            reindexTranscriptsButton.enabled = false
            transcriptsIndexingProgressIndicator.startAnimation(nil)
            transcriptsIndexingProgressIndicator.hidden = false
        }
    }
    
    @IBAction func reindexTranscripts(sender: NSButton) {
        do {
            WWDCDatabase.sharedDatabase.realm.beginWrite()
            WWDCDatabase.sharedDatabase.realm.delete(WWDCDatabase.sharedDatabase.realm.objects(Transcript.self))
            try WWDCDatabase.sharedDatabase.realm.commitWrite()
        } catch let error as NSError {
            mainQ { NSAlert(error: error).runModal() }
        }
        
        let allSessionKeys = WWDCDatabase.sharedDatabase.realm.objects(Session.self).map({ $0.uniqueId })
        WWDCDatabase.sharedDatabase.indexTranscriptsForSessionsWithKeys(allSessionKeys)
    }
    
}
