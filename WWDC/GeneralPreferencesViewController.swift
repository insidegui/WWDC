//
//  GeneralPreferencesViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class GeneralPreferencesViewController: NSViewController {
    
    static func loadFromStoryboard() -> GeneralPreferencesViewController {
        let vc = NSStoryboard(name: "Preferences", bundle: nil).instantiateController(withIdentifier: "GeneralPreferencesViewController")
        
        return vc as! GeneralPreferencesViewController
    }
    
    @IBOutlet weak var includeTranscriptsLabel: NSTextField!
    @IBOutlet weak var includeBookmarksLabel: NSTextField!
    @IBOutlet weak var refreshPeriodicallyLabel: NSTextField!
    
    @IBOutlet weak var searchInTranscriptsSwitch: ITSwitch!
    @IBOutlet weak var searchInBookmarksSwitch: ITSwitch!
    @IBOutlet weak var refreshPeriodicallySwitch: ITSwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        includeTranscriptsLabel.textColor = .prefsPrimaryText
        includeBookmarksLabel.textColor = .prefsPrimaryText
        refreshPeriodicallyLabel.textColor = .prefsPrimaryText
        
        searchInTranscriptsSwitch.tintColor = .primary
        searchInBookmarksSwitch.tintColor = .primary
        refreshPeriodicallySwitch.tintColor = .primary
        
        searchInTranscriptsSwitch.checked = Preferences.shared.searchInTranscripts
        searchInBookmarksSwitch.checked = Preferences.shared.searchInBookmarks
        refreshPeriodicallySwitch.checked = Preferences.shared.refreshPeriodically
    }
    
    @IBAction func searchInTranscriptsSwitchAction(_ sender: Any) {
        Preferences.shared.searchInTranscripts = searchInTranscriptsSwitch.checked
    }
    
    @IBAction func searchInBookmarksSwitchAction(_ sender: Any) {
        Preferences.shared.searchInBookmarks = searchInBookmarksSwitch.checked
    }
    
    @IBAction func refreshPeriodicallySwitchAction(_ sender: Any) {
        Preferences.shared.refreshPeriodically = refreshPeriodicallySwitch.checked
    }
}
