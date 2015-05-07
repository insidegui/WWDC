//
//  PreferencesWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 01/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController {

    convenience init() {
        self.init(windowNibName: "PreferencesWindowController")
    }
    
    let prefs = Preferences.SharedPreferences()
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        populateFontsPopup()
        
        downloadsFolderLabel.stringValue = prefs.localVideoStoragePath
        
        if let familyName = prefs.transcriptFont.familyName {
            fontPopUp.selectItemWithTitle(familyName)
        }
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
    
    @IBAction func revealInFinder(sender: NSButton) {
        let path = Preferences.SharedPreferences().localVideoStoragePath
        let root = path.stringByDeletingLastPathComponent
        NSWorkspace.sharedWorkspace().selectFile(path, inFileViewerRootedAtPath: root)
    }
    
    // MARK: Transcript appearance
    
    @IBOutlet weak var fontPopUp: NSPopUpButton!
    @IBOutlet weak var textColorWell: NSColorWell!
    @IBOutlet weak var bgColorWell: NSColorWell!
    
    @IBAction func fontPopUpAction(sender: NSPopUpButton) {
        if let newFont = NSFont(name: fontPopUp.selectedItem!.title, size: prefs.transcriptFont.pointSize) {
            prefs.transcriptFont = newFont
        }
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
}
