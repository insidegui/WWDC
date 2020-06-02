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
    weak var userDataSyncEngine: UserDataSyncEngine? {
        didSet {
            bindSyncEngine()
        }
    }
    #endif

    private(set) var syncEngine: SyncEngine!

    static func loadFromStoryboard(syncEngine: SyncEngine) -> GeneralPreferencesViewController {
        // swiftlint:disable:next force_cast
        let vc = NSStoryboard(name: .preferences, bundle: nil).instantiateController(withIdentifier: .generalPreferencesViewController) as! GeneralPreferencesViewController

        vc.syncEngine = syncEngine

        return vc
    }

    @IBOutlet weak var searchInTranscriptsSwitch: NSSwitch!
    @IBOutlet weak var searchInBookmarksSwitch: NSSwitch!
    @IBOutlet weak var refreshPeriodicallySwitch: NSSwitch!
    @IBOutlet weak var enableUserDataSyncSwitch: NSSwitch!

    @IBOutlet weak var downloadsFolderLabel: NSTextField!

    @IBOutlet weak var downloadsFolderIntroLabel: NSTextField!
    @IBOutlet weak var searchIntroLabel: NSTextField!
    @IBOutlet weak var includeBookmarksLabel: NSTextField!
    @IBOutlet weak var includeTranscriptsLabel: NSTextField!
    @IBOutlet weak var refreshAutomaticallyLabel: NSTextField!
    @IBOutlet weak var enableUserDataSyncLabel: NSTextField!
    @IBOutlet weak var syncDescriptionLabel: NSTextField!
    @IBOutlet weak var transcriptLanguagesPopUp: NSPopUpButton!
    @IBOutlet weak var loadingLanguagesSpinner: NSProgressIndicator!
    @IBOutlet weak var languagesDescriptionLabel: NSTextField!
    @IBOutlet weak var indexingProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var indexingLabel: NSTextField!

    @IBOutlet weak var dividerA: NSBox!
    @IBOutlet weak var dividerB: NSBox!
    @IBOutlet weak var dividerC: NSBox!
    @IBOutlet weak var dividerE: NSBox!

    override func viewDidLoad() {
        super.viewDidLoad()

        downloadsFolderIntroLabel.textColor = .prefsPrimaryText
        searchIntroLabel.textColor = .prefsPrimaryText
        includeBookmarksLabel.textColor = .prefsPrimaryText
        includeTranscriptsLabel.textColor = .prefsPrimaryText
        refreshAutomaticallyLabel.textColor = .prefsPrimaryText
        downloadsFolderLabel.textColor = .prefsSecondaryText
        enableUserDataSyncLabel.textColor = .prefsPrimaryText
        syncDescriptionLabel.textColor = .prefsSecondaryText
        languagesDescriptionLabel.textColor = .prefsSecondaryText

        dividerA.fillColor = .separatorColor
        dividerB.fillColor = .separatorColor
        dividerC.fillColor = .separatorColor
        dividerE.fillColor = .separatorColor

        searchInTranscriptsSwitch.isOn = Preferences.shared.searchInTranscripts
        searchInBookmarksSwitch.isOn = Preferences.shared.searchInBookmarks
        refreshPeriodicallySwitch.isOn = Preferences.shared.refreshPeriodically
        enableUserDataSyncSwitch.isOn = Preferences.shared.syncUserData

        downloadsFolderLabel.stringValue = Preferences.shared.localVideoStorageURL.path

        bindSyncEngine()
        bindLanguages()
        bindTranscriptIndexingState()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        languagesProvider.fetchAvailableLanguages()
    }

    private let disposeBag = DisposeBag()

    private var dummyRelay = BehaviorRelay<Bool>(value: false)

    private func bindSyncEngine() {
        #if ICLOUD
        guard let engine = userDataSyncEngine, isViewLoaded else { return }

        // Disable sync switch while there are sync operations running
        engine.isPerformingSyncOperation.asDriver()
                                        .map({ !$0 })
                                        .drive(enableUserDataSyncSwitch.rx.isEnabled)
                                        .disposed(by: disposeBag)
        #else
        enableUserDataSyncSwitch?.isHidden = true
        syncDescriptionLabel?.isHidden = true
        #endif
    }

    private func bindTranscriptIndexingState() {
        // Disable transcript language pop up while indexing transcripts.

        syncEngine.isIndexingTranscripts.asDriver()
                                        .map({ !$0 })
                                        .drive(transcriptLanguagesPopUp.rx.isEnabled)
                                        .disposed(by: disposeBag)

        // Show indexing progress while indexing.

        syncEngine.isIndexingTranscripts.asObservable()
                                         .observeOn(MainScheduler.instance)
                                         .bind { [weak self] isIndexing in
            guard let self = self else { return }

            if isIndexing {
                self.indexingLabel?.isHidden = false
                self.indexingProgressIndicator?.isHidden = false
                self.indexingProgressIndicator?.startAnimation(nil)
            } else {
                self.indexingLabel?.isHidden = true
                self.indexingProgressIndicator?.isHidden = true
                self.indexingProgressIndicator?.stopAnimation(nil)
            }
        }.disposed(by: disposeBag)

        syncEngine.transcriptIndexingProgress.asObservable()
                                             .observeOn(MainScheduler.instance)
                                             .bind { [weak self] progress in
            self?.indexingProgressIndicator?.doubleValue = Double(progress)
        }.disposed(by: disposeBag)
    }

    @IBAction func searchInTranscriptsSwitchAction(_ sender: Any) {
        Preferences.shared.searchInTranscripts = searchInTranscriptsSwitch.isOn
    }

    @IBAction func searchInBookmarksSwitchAction(_ sender: Any) {
        Preferences.shared.searchInBookmarks = searchInBookmarksSwitch.isOn
    }

    @IBAction func refreshPeriodicallySwitchAction(_ sender: Any) {
        Preferences.shared.refreshPeriodically = refreshPeriodicallySwitch.isOn
    }

    @IBAction func enableUserDataSyncSwitchAction(_ sender: Any) {
        #if ICLOUD
        Preferences.shared.syncUserData = enableUserDataSyncSwitch.isOn
        userDataSyncEngine?.isEnabled = enableUserDataSyncSwitch.isOn
        #endif
    }

    // MARK: - Downloads folder

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

    private lazy var dangerousLocalStoragePaths: [String] = {
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
        guard !dangerousLocalStoragePaths.contains(url.path) else {
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

    // MARK: - Transcript languages

    private lazy var languagesProvider = TranscriptLanguagesProvider()

    private func showLanguagesLoading() {
        transcriptLanguagesPopUp.isHidden = true
        loadingLanguagesSpinner.isHidden = false
        loadingLanguagesSpinner.startAnimation(self)
    }

    private func hideLanguagesLoading() {
        transcriptLanguagesPopUp.isHidden = false
        loadingLanguagesSpinner.isHidden = true
        loadingLanguagesSpinner.stopAnimation(self)
    }

    private func bindLanguages() {
        showLanguagesLoading()

        languagesProvider.availableLanguageCodes
            .observeOn(MainScheduler.instance)
            .bind { [weak self] languages in
                self?.populateLanguagesPopUp(with: languages)
            }
            .disposed(by: disposeBag)
    }

    private func populateLanguagesPopUp(with languages: [TranscriptLanguage]) {
        guard !languages.isEmpty else { return }

        transcriptLanguagesPopUp.removeAllItems()

        languages.forEach { lang in
            let item = NSMenuItem(title: lang.name, action: nil, keyEquivalent: "")
            item.representedObject = lang
            transcriptLanguagesPopUp.menu?.addItem(item)
        }

        if let selectedLang = languages.first(where: { $0.code == Preferences.shared.transcriptLanguageCode }) {
            transcriptLanguagesPopUp.selectItem(withTitle: selectedLang.name)
        }

        hideLanguagesLoading()
    }

    @IBAction func transcriptLanguagesPopUpAction(_ sender: NSPopUpButton) {
        guard let lang = sender.selectedItem?.representedObject as? TranscriptLanguage else { return }

        Preferences.shared.transcriptLanguageCode = lang.code
    }

}

extension NSSwitch {
    var isOn: Bool {
        get { state == .on }
        set { state = newValue ? .on : .off }
    }
}
