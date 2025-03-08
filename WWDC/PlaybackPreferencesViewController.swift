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

final class PlaybackPreferencesViewController: WWDCWindowContentViewController {

    static func loadFromStoryboard() -> PlaybackPreferencesViewController {
        // swiftlint:disable:next force_cast
        return NSStoryboard(name: .preferences, bundle: nil).instantiateController(withIdentifier: .playbackPreferencesViewController) as! PlaybackPreferencesViewController
    }

    @IBOutlet weak var skipIntroStackView: NSStackView?
    @IBOutlet private var skipIntroSwitch: NSSwitch!
    @IBOutlet weak var skipDurationDropDownMenu: NSPopUpButtonCell!
    @IBOutlet weak var includeAppBannerInClipsSwitch: NSSwitch!

    override var viewForWindowTopSafeAreaConstraint: NSView? { skipIntroSwitch }

    override func viewDidLoad() {
        super.viewDidLoad()

        skipIntroSwitch.isOn = Preferences.shared.skipIntro
        switch Preferences.shared.skipBackAndForwardDuration {
        case .fiveSeconds:
            skipDurationDropDownMenu.selectItem(at: 0)
        case .tenSeconds:
            skipDurationDropDownMenu.selectItem(at: 1)
        case .fifteenSeconds:
            skipDurationDropDownMenu.selectItem(at: 2)
        case .thirtySeconds:
            skipDurationDropDownMenu.selectItem(at: 3)
        }
        includeAppBannerInClipsSwitch.isOn = Preferences.shared.includeAppBannerInSharedClips
    }

    @IBAction func skipIntroSwitchAction(_ sender: Any) {
        Preferences.shared.skipIntro = skipIntroSwitch.isOn
    }

    @IBAction func skipBackAndForwardDurationChangedAction(_ sender: Any) {
        switch skipDurationDropDownMenu?.indexOfSelectedItem {
        case 0:
            Preferences.shared.skipBackAndForwardDuration = .fiveSeconds
        case 1:
            Preferences.shared.skipBackAndForwardDuration = .tenSeconds
        case 2:
            Preferences.shared.skipBackAndForwardDuration = .fifteenSeconds
        case 3:
            Preferences.shared.skipBackAndForwardDuration = .thirtySeconds
        default:
            break
        }
    }

    @IBAction func includeAppBannerInClipsSwitchAction(_ sender: NSSwitch) {
        Preferences.shared.includeAppBannerInSharedClips = includeAppBannerInClipsSwitch.isOn
    }
    
}
