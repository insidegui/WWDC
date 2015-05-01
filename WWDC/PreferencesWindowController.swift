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
    
    override func windowDidLoad() {
        super.windowDidLoad()

        downloadsFolderLabel.stringValue = Preferences.SharedPreferences().localVideoStoragePath
    }
    
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
}
