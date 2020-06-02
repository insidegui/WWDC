//
//  PlaybackPreferencesViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 30/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSStoryboard.SceneIdentifier {
    static let playbackPreferencesViewController = NSStoryboard.SceneIdentifier("PlaybackPreferencesViewController")
}

final class PlaybackPreferencesViewController: NSViewController {

    static func loadFromStoryboard() -> PlaybackPreferencesViewController {
        // swiftlint:disable:next force_cast
        return NSStoryboard(name: .preferences, bundle: nil).instantiateController(withIdentifier: .playbackPreferencesViewController) as! PlaybackPreferencesViewController
    }

    @IBOutlet private var skipIntroSwitch: NSSwitch!
    @IBOutlet private var skipBackAndForwardBy30SecondsSwitch: NSSwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        skipIntroSwitch.isOn = Preferences.shared.skipIntro
        skipBackAndForwardBy30SecondsSwitch.isOn = Preferences.shared.skipBackAndForwardBy30Seconds
    }

    @IBAction func skipIntroSwitchAction(_ sender: Any) {
        Preferences.shared.skipIntro = skipIntroSwitch.isOn
    }

    @IBAction func skipBackAndForwardBy30SecondsSwitchAction(_ sender: Any) {
        Preferences.shared.skipBackAndForwardBy30Seconds = skipBackAndForwardBy30SecondsSwitch.isOn
    }
    
}
