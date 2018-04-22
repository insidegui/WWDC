//
//  AppCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import RxSwift
import ConfCore
import PlayerUI
import ThrowBack

final class AppCoordinator {

    private let disposeBag = DisposeBag()

    var liveObserver: LiveObserver

    var storage: Storage
    var syncEngine: SyncEngine

    var windowController: MainWindowController
    var tabController: WWDCTabViewController<MainWindowTab>

    var scheduleController: SessionsSplitViewController
    var videosController: SessionsSplitViewController

    var currentPlayerController: VideoPlayerViewController?

    var currentActivity: NSUserActivity?

    var activeTab: MainWindowTab = .schedule

    /// The tab that "owns" the current player (the one that was active when the "play" button was pressed)
    var playerOwnerTab: MainWindowTab?

    /// The session that "owns" the current player (the one that was selected on the active tab when "play" was pressed)
    var playerOwnerSessionIdentifier: String?

    /// Whether playback can be restored to the previous context when exiting PiP mode (go back to tab/session)
    var canRestorePlaybackContext = false

    /// Whether we're currently in the middle of a player context transition
    var isTransitioningPlayerContext = false

    init(windowController: MainWindowController) {
        do {
            let supportPath = try PathUtil.appSupportPathCreatingIfNeeded()

            let filePath = supportPath + "/ConfCore.realm"

            var realmConfig = Realm.Configuration(fileURL: URL(fileURLWithPath: filePath))
            realmConfig.schemaVersion = Constants.coreSchemaVersion

            let client = AppleAPIClient(environment: .current)

            storage = try Storage(realmConfig)

            syncEngine = SyncEngine(storage: storage, client: client)
        } catch {
            fatalError("Realm initialization error: \(error)")
        }

        DownloadManager.shared.start(with: storage)

        liveObserver = LiveObserver(dateProvider: today, storage: storage)

        // Primary UI Intialization

        tabController = WWDCTabViewController(windowController: windowController)

        // Schedule
        scheduleController = SessionsSplitViewController(windowController: windowController, listStyle: .schedule)
        scheduleController.identifier = NSUserInterfaceItemIdentifier(rawValue: "Schedule")
        scheduleController.splitView.identifier = NSUserInterfaceItemIdentifier(rawValue: "ScheduleSplitView")
        scheduleController.splitView.autosaveName = NSSplitView.AutosaveName(rawValue: "ScheduleSplitView")
        let scheduleItem = NSTabViewItem(viewController: scheduleController)
        scheduleItem.label = "Schedule"
        scheduleItem.initialFirstResponder = scheduleController.listViewController.tableView
        tabController.addTabViewItem(scheduleItem)

        // Videos
        videosController = SessionsSplitViewController(windowController: windowController, listStyle: .videos)
        videosController.identifier = NSUserInterfaceItemIdentifier(rawValue: "Videos")
        videosController.splitView.identifier = NSUserInterfaceItemIdentifier(rawValue: "VideosSplitView")
        videosController.splitView.autosaveName = NSSplitView.AutosaveName(rawValue: "VideosSplitView")
        let videosItem = NSTabViewItem(viewController: videosController)
        videosItem.label = "Videos"
        videosItem.initialFirstResponder = videosController.listViewController.tableView
        tabController.addTabViewItem(videosItem)

        self.windowController = windowController

        restoreApplicationState()

        setupBindings()
        setupDelegation()

        _ = NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: nil) { _ in self.startup() }
        _ = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in self.saveApplicationState() }
        _ = NotificationCenter.default.addObserver(forName: .RefreshPeriodicallyPreferenceDidChange, object: nil, queue: nil, using: { _  in self.resetAutorefreshTimer() })
    }

    /// The list controller for the active tab
    var currentListController: SessionsTableViewController {
        switch activeTab {
        case .schedule:
            return scheduleController.listViewController
        case .videos:
            return videosController.listViewController
        }
    }

    /// The session that is currently selected on the videos tab (observable)
    var selectedSession: Observable<SessionViewModel?> {
        return videosController.listViewController.selectedSession.asObservable()
    }

    /// The session that is currently selected on the schedule tab (observable)
    var selectedScheduleItem: Observable<SessionViewModel?> {
        return scheduleController.listViewController.selectedSession.asObservable()
    }

    /// The session that is currently selected on the videos tab
    var selectedSessionValue: SessionViewModel? {
        return videosController.listViewController.selectedSession.value
    }

    /// The session that is currently selected on the schedule tab
    var selectedScheduleItemValue: SessionViewModel? {
        return scheduleController.listViewController.selectedSession.value
    }

    /// The selected session's view model, regardless of which tab it is selected in
    var selectedViewModelRegardlessOfTab: SessionViewModel?

    /// The viewModel for the current playback session
    var currentPlaybackViewModel: PlaybackViewModel? {
        didSet {
            observeNowPlayingInfo()
        }
    }

    private func setupBindings() {
        tabController.rxActiveTab.subscribe(onNext: { [weak self] activeTab in

            self?.activeTab = activeTab

            self?.updateSelectedViewModelRegardlessOfTab()
        }).disposed(by: disposeBag)

        selectedSession.subscribeOn(MainScheduler.instance).subscribe(onNext: { [weak self] viewModel in
            self?.videosController.detailViewController.viewModel = viewModel
            self?.updateSelectedViewModelRegardlessOfTab()
        }).disposed(by: disposeBag)

        selectedScheduleItem.subscribeOn(MainScheduler.instance).subscribe(onNext: { [weak self] viewModel in
            self?.scheduleController.detailViewController.viewModel = viewModel
            self?.updateSelectedViewModelRegardlessOfTab()
        }).disposed(by: disposeBag)
    }

    private func updateSelectedViewModelRegardlessOfTab() {
        switch activeTab {
        case .schedule:
            selectedViewModelRegardlessOfTab = selectedScheduleItemValue
        case .videos:
            selectedViewModelRegardlessOfTab = selectedSessionValue
        }

        updateShelfBasedOnSelectionChange()
        updateCurrentActivity(with: selectedViewModelRegardlessOfTab)
    }

    private func setupDelegation() {
        let videoDetail = videosController.detailViewController

        videoDetail.shelfController.delegate = self
        videoDetail.summaryController.actionsViewController.delegate = self

        let scheduleDetail = scheduleController.detailViewController

        scheduleDetail.shelfController.delegate = self
        scheduleDetail.summaryController.actionsViewController.delegate = self

        videosController.listViewController.delegate = self
        scheduleController.listViewController.delegate = self
    }

    private func updateListsAfterSync(migrate: Bool = false) {
        if migrate {
            presentMigrationInterfaceIfNeeded { [weak self] in
                self?.doUpdateLists()
                self?.showAccountPreferencesIfAppropriate()
            }
        } else {
            doUpdateLists()
        }

        DownloadManager.shared.syncWithFileSystem()
    }

    private func doUpdateLists() {

        let starupDependencies = Observable.combineLatest(storage.tracksObservable,
                                                          storage.eventsObservable,
                                                          storage.focusesObservable,
                                                          storage.scheduleObservable)

        starupDependencies
            .filter { !$0.0.isEmpty && !$0.1.isEmpty && !$0.2.isEmpty && !$0.3.isEmpty }
            .take(1)
            .subscribe(onNext: { [weak self] tracks, _, _, sections in
                guard let `self` = self else { return }

                self.tabController.hideLoading()
                self.searchCoordinator.configureFilters()

                // Currently these two things must happen together and in this order for
                // new information to be displayed. It's not ideal
                self.videosController.listViewController.sessionRowProvider = VideosSessionRowProvider(tracks: tracks)
                self.searchCoordinator.applyVideosFilters()

                // Currently these two things must happen together and in this order for
                // new information to be displayed. It's not ideal
                self.scheduleController.listViewController.sessionRowProvider = ScheduleSessionRowProvider(scheduleSections: sections)
                self.scrollToTodayIfWWDC()
                self.searchCoordinator.applyScheduleFilters()
            }).disposed(by: disposeBag)

        liveObserver.start()
    }

    private lazy var searchCoordinator: SearchCoordinator = {
        return SearchCoordinator(self.storage,
                                 sessionsController: self.scheduleController.listViewController,
                                 videosController: self.videosController.listViewController,
                                 restorationFiltersState: Preferences.shared.filtersState)
    }()

    private func startup() {
        RemoteEnvironment.shared.start()

        ContributorsFetcher.shared.load()

        windowController.contentViewController = tabController
        windowController.showWindow(self)

        if storage.isEmpty {
            tabController.showLoading()
        }

        _ = NotificationCenter.default.addObserver(forName: .SyncEngineDidSyncSessionsAndSchedule, object: nil, queue: .main) { note in
            if let error = note.object as? Error {
                NSApp.presentError(error)
            } else {
                self.updateListsAfterSync(migrate: true)
            }
        }

        _ = NotificationCenter.default.addObserver(forName: .WWDCEnvironmentDidChange, object: nil, queue: .main) { _ in
            self.refresh(nil)
        }

        refresh(nil)
        updateListsAfterSync()

        if Arguments.showPreferences {
            showPreferences(nil)
        } else {
            showAccountPreferencesIfAppropriate()
        }
    }

    private func showAccountPreferencesIfAppropriate() {
        guard !Preferences.shared.showedAccountPromptAtStartup else { return }

        guard TBUserDataMigrator.presentedMigrationPrompt else { return }

        Preferences.shared.showedAccountPromptAtStartup = true

        showAccountPreferences()
    }

    func receiveNotification(with userInfo: [String: Any]) -> Bool {
        return liveObserver.processSubscriptionNotification(with: userInfo) ||
            RemoteEnvironment.shared.processSubscriptionNotification(with: userInfo)
    }

    // MARK: - Now playing info

    private var nowPlayingInfoBag = DisposeBag()

    private func observeNowPlayingInfo() {
        nowPlayingInfoBag = DisposeBag()

        currentPlaybackViewModel?.nowPlayingInfo.asObservable().subscribe(onNext: { [weak self] _ in
            self?.publishNowPlayingInfo()
        }).disposed(by: nowPlayingInfoBag)
    }

    // MARK: - State restoration

    private func saveApplicationState() {
        Preferences.shared.activeTab = activeTab
        if let identifier = selectedScheduleItemValue?.identifier {
            Preferences.shared.selectedScheduleItemIdentifier = identifier
        }
        if let identifier = selectedSessionValue?.identifier {
            Preferences.shared.selectedVideoItemIdentifier = identifier
        }
        Preferences.shared.filtersState = searchCoordinator.currentFiltersState()
    }

    private func restoreApplicationState() {

        let activeTab = Preferences.shared.activeTab
        tabController.activeTab = activeTab

        if let identifier = Preferences.shared.selectedScheduleItemIdentifier {
            scheduleController.listViewController.selectSession(with: identifier, deferIfNeeded: true)
        }

        if let identifier = Preferences.shared.selectedVideoItemIdentifier {
            videosController.listViewController.selectSession(with: identifier, deferIfNeeded: true)
        }
    }

    private func scrollToTodayIfWWDC() {
        guard liveObserver.isWWDCWeek else { return }

        scheduleController.listViewController.scrollToToday()
    }

    // MARK: - Deep linking

    func handle(link: DeepLink, deferIfNeeded: Bool) {

        if link.isForCurrentYear {
            tabController.activeTab = .schedule
            scheduleController.listViewController.selectSession(with: link.sessionIdentifier, deferIfNeeded: true)
        } else {
            tabController.activeTab = .videos
            videosController.listViewController.selectSession(with: link.sessionIdentifier, deferIfNeeded: true)
        }
    }

    // MARK: - Preferences

    private lazy var preferencesCoordinator: PreferencesCoordinator = PreferencesCoordinator()

    func showAccountPreferences() {
        preferencesCoordinator.show(in: .account)
    }

    func showPreferences(_ sender: Any?) {
        preferencesCoordinator.show()
    }

    // MARK: - About window

    fileprivate lazy var aboutWindowController: AboutWindowController = {
        var aboutWC = AboutWindowController(infoText: ContributorsFetcher.shared.infoText)

        ContributorsFetcher.shared.infoTextChangedCallback = { [unowned self] newText in
            self.aboutWindowController.infoText = newText
        }

        return aboutWC
    }()

    func showAboutWindow() {
        aboutWindowController.showWindow(nil)
    }

    // MARK: - Refresh

    /// Used to prevent the refresh system from being spammed. Resetting
    /// NSBackgroundActivitySchedule can result in the scheduled activity happening immediately
    /// especially if the `interval` is sufficiently low.
    private var lastRefresh = Date.distantPast

    func refresh(_ sender: Any?) {
        let now = Date()
        guard now.timeIntervalSince(lastRefresh) > 5 else { return }
        lastRefresh = now

        DispatchQueue.main.async {
            self.syncEngine.syncContent()
            self.syncEngine.syncLiveVideos()

            self.liveObserver.refresh()

            if self.autorefreshActivity == nil
                || (sender as? NSBackgroundActivityScheduler) !== self.autorefreshActivity {
                self.resetAutorefreshTimer()
            }
        }
    }

    private var autorefreshActivity: NSBackgroundActivityScheduler?

    func makeAutorefreshActivity() -> NSBackgroundActivityScheduler {
        let activityScheduler = NSBackgroundActivityScheduler(identifier: "io.wwdc.autorefresh.backgroundactivity")
        activityScheduler.interval = Constants.autorefreshInterval
        activityScheduler.repeats = true
        activityScheduler.qualityOfService = .utility
        activityScheduler.schedule { [weak self] completion in
            self?.refresh(self?.autorefreshActivity)
            completion(.finished)
        }

        return activityScheduler
    }

    private func resetAutorefreshTimer() {
        autorefreshActivity?.invalidate()
        autorefreshActivity = Preferences.shared.refreshPeriodically ? makeAutorefreshActivity() : nil
    }

    // MARK: - Data migration

    private var userIsThinkingVeryHardAboutMigration = false

    private var migrator: TBUserDataMigrator!

    private func presentMigrationInterfaceIfNeeded(completion: @escaping () -> Void) {
        guard !ProcessInfo.processInfo.arguments.contains("--skip-migration") else {
            completion()
            return
        }

        guard !userIsThinkingVeryHardAboutMigration else { return }

        userIsThinkingVeryHardAboutMigration = true

        if migrator != nil { guard !migrator.isPerformingMigration else { return } }

        let legacyURL = URL(fileURLWithPath: PathUtil.appSupportPathAssumingExisting + "/default.realm")
        migrator = TBUserDataMigrator(legacyDatabaseFileURL: legacyURL, newRealm: storage.realm)

        guard migrator.needsMigration && !TBUserDataMigrator.presentedMigrationPrompt else {
            completion()
            return
        }

        let alert = WWDCAlert.create()
        alert.messageText = "Migrate your data"
        alert.informativeText = "I noticed you have a previous version's data on your Mac. Do you want to migrate your preferences, favorites and other user data to the new version?\n\nNOTICE: if you import your data, old versions of the app will no longer work on this computer."

        alert.addButton(withTitle: "Migrate Data")
        alert.addButton(withTitle: "Start Fresh")
        alert.addButton(withTitle: "Quit")

        enum Choice: Int {
            case migrate = 1000
            case startFresh = 1001
            case quit = 1002
        }

        guard let choice = Choice(rawValue: alert.runModal().rawValue) else { return }

        switch choice {
        case .migrate:
            migrator.performMigration { [weak self] result in
                self?.migrationFinished(with: result, completion: completion)
            }
        case .startFresh:
            completion()
        case .quit:
            NSApp.terminate(nil)
        }

        TBUserDataMigrator.presentedMigrationPrompt = true
    }

    private func migrationFinished(with result: TBMigrationResult, completion: @escaping () -> Void) {
        switch result {
        case .failed(let error):
            WWDCAlert.show(with: error)
        default: break
        }

        completion()
    }

}
