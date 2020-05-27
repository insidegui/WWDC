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

extension NSStoryboard.Name {
    static let preferences = NSStoryboard.Name("Preferences")
}

extension NSStoryboard.SceneIdentifier {
    static let generalPreferencesViewController = NSStoryboard.SceneIdentifier("GeneralPreferencesViewController")
}

class GeneralPreferencesViewController: NSViewController {

    #if ICLOUD
    weak var userDataSyncEngine: UserDataSyncEngine?
    #endif

    static func loadFromStoryboard() -> GeneralPreferencesViewController {
        let vc = NSStoryboard(name: .preferences, bundle: nil).instantiateController(withIdentifier: .generalPreferencesViewController)

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

        guard let window = view.window else { return }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            guard let url = panel.url else { return }

            self?.handleNewDownloadsFolder(url)
        }
    }

    private func handleNewDownloadsFolder(_ url: URL) {
        guard url != Preferences.shared.localVideoStorageURL else { return }

        guard validateDownloadsFolder(url) else { return }

        Preferences.shared.localVideoStorageURL = url
        downloadsFolderLabel.stringValue = url.path
    }

    private lazy var dangeoursLocalStoragePaths: [String] = {
        [
            NSHomeDirectory(),
            "/"
        ]
    }()

    private func showStoragePathError(with message: String) {
        let alert = NSAlert()
        alert.messageText = "Folder can't be used"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func validateDownloadsFolder(_ url: URL) -> Bool {
        guard !dangeoursLocalStoragePaths.contains(url.path) else {
            showStoragePathError(with: "This folder can't be used to store downloaded videos, please choose another one. Downloaded videos can't be stored in the root of your home directory or in the root of the filesystem.")
            return false
        }
        guard let enumerator = FileManager.default.enumerator(atPath: url.path) else {
            showStoragePathError(with: "The app was unable to access the folder you selected.")
            return false
        }

        var rootFileCount = 0

        while let _ = enumerator.nextObject() as? String {
            rootFileCount += 1
        }

        // Let it go through if there are very few files in the folder.
        guard rootFileCount > 3 else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Folder not empty"
        alert.informativeText = "The folder you selected is not empty. We strongly suggest starting out with an empty folder to use for your WWDC downloads. Are you sure you'd like to use this folder?"
        alert.addButton(withTitle: "Choose Another One")
        alert.addButton(withTitle: "Use \(url.lastPathComponent)")

        let response = alert.runModal()

        return response == .alertSecondButtonReturn
    }

}
