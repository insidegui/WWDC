//
//  GeneralPreferencesViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import ConfCore

class GeneralPreferencesViewController: NSViewController {

    #if ICLOUD
    weak var userDataSyncEngine: UserDataSyncEngine?
    #endif

    static func loadFromStoryboard() -> GeneralPreferencesViewController {
        let vc = NSStoryboard(name: NSStoryboard.Name(rawValue: "Preferences"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "GeneralPreferencesViewController"))

        // swiftlint:disable:next force_cast
        return vc as! GeneralPreferencesViewController
    }

    @IBOutlet weak var searchInTranscriptsSwitch: ITSwitch!
    @IBOutlet weak var searchInBookmarksSwitch: ITSwitch!
    @IBOutlet weak var refreshPeriodicallySwitch: ITSwitch!
    @IBOutlet weak var skipBackAndForwardBy30SecondsSwitch: ITSwitch!
    @IBOutlet weak var enableUserDataSyncSwitch: ITSwitch!

    @IBOutlet weak var downloadsFolderLabel: NSTextField!

    @IBOutlet weak var downloadsFolderIntroLabel: NSTextField!
    @IBOutlet weak var searchIntroLabel: NSTextField!
    @IBOutlet weak var includeBookmarksLabel: NSTextField!
    @IBOutlet weak var includeTranscriptsLabel: NSTextField!
    @IBOutlet weak var refreshAutomaticallyLabel: NSTextField!
    @IBOutlet weak var skipBackAndForwardBy30SecondsLabel: NSTextField!
    @IBOutlet weak var enableUserDataSyncLabel: NSTextField!
    @IBOutlet weak var syncDescriptionLabel: NSTextField!

    @IBOutlet weak var dividerA: NSBox!
    @IBOutlet weak var dividerB: NSBox!
    @IBOutlet weak var dividerC: NSBox!
    @IBOutlet weak var dividerD: NSBox!

    override func viewDidLoad() {
        super.viewDidLoad()

        downloadsFolderIntroLabel.textColor = .prefsPrimaryText
        searchIntroLabel.textColor = .prefsPrimaryText
        includeBookmarksLabel.textColor = .prefsPrimaryText
        includeTranscriptsLabel.textColor = .prefsPrimaryText
        refreshAutomaticallyLabel.textColor = .prefsPrimaryText
        skipBackAndForwardBy30SecondsLabel.textColor = .prefsPrimaryText
        downloadsFolderLabel.textColor = .prefsSecondaryText
        enableUserDataSyncLabel.textColor = .prefsPrimaryText
        syncDescriptionLabel.textColor = .prefsSecondaryText

        dividerA.fillColor = .darkGridColor
        dividerB.fillColor = .darkGridColor
        dividerC.fillColor = .darkGridColor
        dividerD.fillColor = .darkGridColor

        searchInTranscriptsSwitch.tintColor = .primary
        searchInBookmarksSwitch.tintColor = .primary
        refreshPeriodicallySwitch.tintColor = .primary
        skipBackAndForwardBy30SecondsSwitch.tintColor = .primary
        enableUserDataSyncSwitch.tintColor = .primary

        searchInTranscriptsSwitch.checked = Preferences.shared.searchInTranscripts
        searchInBookmarksSwitch.checked = Preferences.shared.searchInBookmarks
        refreshPeriodicallySwitch.checked = Preferences.shared.refreshPeriodically
        skipBackAndForwardBy30SecondsSwitch.checked = Preferences.shared.skipBackAndForwardBy30Seconds
        enableUserDataSyncSwitch.checked = Preferences.shared.syncUserData

        downloadsFolderLabel.stringValue = Preferences.shared.localVideoStorageURL.path

        bindSyncEngine()
    }

    private let disposeBag = DisposeBag()

    private func bindSyncEngine() {
        #if ICLOUD
        guard let engine = userDataSyncEngine, isViewLoaded else { return }

        // Disable sync switch while there are sync operations running
        engine.isPerformingSyncOperation.asDriver()
                                        .map({ !$0 })
                                        .drive(enableUserDataSyncSwitch.rx.isEnabled)
                                        .disposed(by: disposeBag)
        #else
        dividerD?.isHidden = true
        enableUserDataSyncSwitch?.isHidden = true
        syncDescriptionLabel?.isHidden = true
        #endif
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

    @IBAction func skipBackAndForwardBy30SecondsSwitchAction(_ sender: Any) {
        Preferences.shared.skipBackAndForwardBy30Seconds = skipBackAndForwardBy30SecondsSwitch.checked
    }

    @IBAction func enableUserDataSyncSwitchAction(_ sender: Any) {
        #if ICLOUD
        Preferences.shared.syncUserData = enableUserDataSyncSwitch.checked
        userDataSyncEngine?.isEnabled = enableUserDataSyncSwitch.checked
        #endif
    }

    @IBAction func revealDownloadsFolderInFinder(_ sender: NSButton) {
        let url = Preferences.shared.localVideoStorageURL
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    @IBAction func selectDownloadsFolder(_ sender: NSButton) {
        let panel = NSOpenPanel()

        panel.title = "Change Downloads Folder"
        panel.prompt = "Select"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        panel.runModal()

        guard let url = panel.url else { return }

        Preferences.shared.localVideoStorageURL = url
        downloadsFolderLabel.stringValue = url.path
    }

}
