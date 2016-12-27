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
            fontPopUp.selectItem(withTitle: familyName)
        }
        
        let size = "\(Int(prefs.transcriptFont.pointSize))"
        sizePopUp.selectItem(withTitle: size)
        
        textColorWell.color = prefs.transcriptTextColor
        bgColorWell.color = prefs.transcriptBgColor
        
        setupTranscriptIndexingControls()
    }
    
    // MARK: Downloads folder
    
    @IBOutlet weak var downloadsFolderLabel: NSTextField!
    
    @IBAction func changeDownloadsFolder(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: Preferences.SharedPreferences().localVideoStoragePath)
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.beginSheetModal(for: window!) { result in
            if result > 0 {
                if let path = panel.url?.path {
                    Preferences.SharedPreferences().localVideoStoragePath = path
                    self.downloadsFolderLabel.stringValue = path
                }
            }
        }
    }
    
    @IBAction func revealInFinder(_ sender: NSButton) {
        let path = Preferences.SharedPreferences().localVideoStoragePath
        let root = (path as NSString).deletingLastPathComponent

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            } catch _ {
            }
        }

        NSWorkspace.shared().selectFile(path, inFileViewerRootedAtPath: root)
    }
    
    // MARK: Session refresh
    
    @IBOutlet weak var automaticRefreshEnabledCheckbox: NSButton!
    
    @IBAction func automaticRefreshCheckboxAction(_ sender: NSButton) {
        prefs.automaticRefreshEnabled = (sender.state == NSOnState)
    }
    
    // MARK: Transcript appearance
    
    @IBOutlet weak var fontPopUp: NSPopUpButton!
    @IBOutlet weak var sizePopUp: NSPopUpButton!
    @IBOutlet weak var textColorWell: NSColorWell!
    @IBOutlet weak var bgColorWell: NSColorWell!
    
    @IBAction func fontPopUpAction(_ sender: NSPopUpButton) {
        if let newFont = NSFont(name: fontPopUp.selectedItem!.title, size: prefs.transcriptFont.pointSize) {
            prefs.transcriptFont = newFont
        }
    }
    
    @IBAction func sizePopUpAction(_ sender: NSPopUpButton) {
        let size = NSString(string: sizePopUp.selectedItem!.title).doubleValue
        prefs.transcriptFont = NSFont(name: prefs.transcriptFont.fontName, size: CGFloat(size))!
    }
    
    @IBAction func textColorWellAction(_ sender: NSColorWell) {
        prefs.transcriptTextColor = textColorWell.color
    }
    
    @IBAction func bgColorWellAction(_ sender: NSColorWell) {
        prefs.transcriptBgColor = bgColorWell.color
    }
    
    func populateFontsPopup() {
        fontPopUp.addItems(withTitles: NSFontManager.shared().availableFontFamilies)
    }
    
    // MARK: - Transcripts index
    
    @IBOutlet weak var reindexTranscriptsButton: NSButton!
    @IBOutlet weak var transcriptsIndexingProgressIndicator: NSProgressIndicator!
    
    fileprivate var installedIndexingObservers = false
    
    @objc fileprivate func setupTranscriptIndexingControls() {
        if !installedIndexingObservers {
            NotificationCenter.default.addObserver(self, selector: #selector(setupTranscriptIndexingControls), name: NSNotification.Name(rawValue: TranscriptIndexingDidStartNotification), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(setupTranscriptIndexingControls), name: NSNotification.Name(rawValue: TranscriptIndexingDidStopNotification), object: nil)
            
            installedIndexingObservers = true
        }
        
        if !WWDCDatabase.sharedDatabase.isIndexingTranscripts {
            reindexTranscriptsButton.isEnabled = true
            transcriptsIndexingProgressIndicator.stopAnimation(nil)
            transcriptsIndexingProgressIndicator.isHidden = true
        } else {
            reindexTranscriptsButton.isEnabled = false
            transcriptsIndexingProgressIndicator.startAnimation(nil)
            transcriptsIndexingProgressIndicator.isHidden = false
        }
    }
    
    @IBAction func reindexTranscripts(_ sender: NSButton) {
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
