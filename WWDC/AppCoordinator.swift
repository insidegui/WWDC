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
import os.log

final class AppCoordinator {

    let log = OSLog(subsystem: "WWDC", category: "AppCoordinator")
    private let disposeBag = DisposeBag()

    var liveObserver: LiveObserver

    var storage: Storage
    var syncEngine: SyncEngine

    var windowController: MainWindowController
    var tabController: WWDCTabViewController<MainWindowTab>

    #if FEATURED_TAB_ENABLED
    var featuredController: FeaturedContentViewController
    #endif
    var scheduleController: SessionsSplitViewController
    var videosController: SessionsSplitViewController

    var currentPlayerController: VideoPlayerViewController?

    var currentActivity: NSUserActivity?

    var activeTab: MainWindowTab = .schedule

    /// The tab that "owns" the current player (the one that was active when the "play" button was pressed)
    var playerOwnerTab: MainWindowTab?

    /// The session that "owns" the current player (the one that was selected on the active tab when "play" was pressed)
    var playerOwnerSessionIdentifier: String?

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
            #if ICLOUD
            syncEngine.userDataSyncEngine.isEnabled = Preferences.shared.syncUserData
            #endif
        } catch {
            fatalError("Realm initialization error: \(error)")
        }

        DownloadManager.shared.start(with: storage)

        liveObserver = LiveObserver(dateProvider: today, storage: storage, syncEngine: syncEngine)

        // Primary UI Intialization

        tabController = WWDCTabViewController(windowController: windowController)

        #if FEATURED_TAB_ENABLED
        // Featured
        featuredController = FeaturedContentViewController()
        featuredController.identifier = NSUserInterfaceItemIdentifier(rawValue: "Featured")
        let featuredItem = NSTabViewItem(viewController: featuredController)
        featuredItem.label = "Featured"
        tabController.addTabViewItem(featuredItem)
        #endif

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

        NSApp.isAutomaticCustomizeTouchBarMenuItemEnabled = true
    }

    /// The list controller for the active tab
    var currentListController: SessionsTableViewController? {
        switch activeTab {
        case .schedule:
            return scheduleController.listViewController
        case .videos:
            return videosController.listViewController
        default:
            return nil
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

        func bind(session: Observable<SessionViewModel?>, to detailsController: SessionDetailsViewController) {

            session.subscribeOn(MainScheduler.instance).subscribe(onNext: { [weak self] viewModel in
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.35

                    detailsController.viewModel = viewModel
                    self?.updateSelectedViewModelRegardlessOfTab()
                })

            }).disposed(by: disposeBag)
        }

        bind(session: selectedSession, to: videosController.detailViewController)

        bind(session: selectedScheduleItem, to: scheduleController.detailViewController)
    }

    private func updateSelectedViewModelRegardlessOfTab() {
        switch activeTab {
        case .schedule:
            selectedViewModelRegardlessOfTab = selectedScheduleItemValue
        case .videos:
            selectedViewModelRegardlessOfTab = selectedSessionValue
        default:
            selectedViewModelRegardlessOfTab = nil
        }

        updateShelfBasedOnSelectionChange()
        updateCurrentActivity(with: selectedViewModelRegardlessOfTab)
    }

    func selectSessionOnAppropriateTab(with viewModel: SessionViewModel) {

        if currentListController?.canDisplay(session: viewModel) == true {
            currentListController?.select(session: viewModel)
            return
        }

        if videosController.listViewController.canDisplay(session: viewModel) {
            videosController.listViewController.select(session: viewModel)
            tabController.activeTab = .videos

        } else if scheduleController.listViewController.canDisplay(session: viewModel) {
            scheduleController.listViewController.select(session: viewModel)
            tabController.activeTab = .schedule
        }
    }

    private func setupDelegation() {
        let videoDetail = videosController.detailViewController

        videoDetail.shelfController.delegate = self
        videoDetail.summaryController.actionsViewController.delegate = self
        videoDetail.summaryController.relatedSessionsViewController.delegate = self

        let scheduleDetail = scheduleController.detailViewController

        scheduleDetail.shelfController.delegate = self
        scheduleDetail.summaryController.actionsViewController.delegate = self
        scheduleDetail.summaryController.relatedSessionsViewController.delegate = self

        videosController.listViewController.delegate = self
        scheduleController.listViewController.delegate = self

        #if FEATURED_TAB_ENABLED
        featuredController.delegate = self
        #endif
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

        // Initial app launch waits for all of these things to be loaded before dismissing the primary loading spinner
        // It may, however, delay the presentation of content on tabs that already have everything they need

        let starupDependencies = Observable.combineLatest(storage.tracksObservable,
                                                          storage.eventsObservable,
                                                          storage.focusesObservable,
                                                          storage.scheduleObservable,
                                                          storage.featuredSectionsObservable)

        starupDependencies
            .filter {
                var result = !$0.0.isEmpty && !$0.1.isEmpty && !$0.2.isEmpty && !$0.3.isEmpty
                #if FEATURED_TAB_ENABLED
                result = result && !$0.4.isEmpty
                #endif
                return result
            }
            .take(1)
            .subscribe(onNext: { [weak self] tracks, _, _, sections, _ in
                guard let `self` = self else { return }

                self.tabController.hideLoading()
                self.searchCoordinator.configureFilters()

                self.videosController.listViewController.sessionRowProvider = VideosSessionRowProvider(tracks: tracks)

                self.scheduleController.listViewController.sessionRowProvider = ScheduleSessionRowProvider(scheduleSections: sections)
                self.scrollToTodayIfWWDC()
            }).disposed(by: disposeBag)

        liveObserver.start()
    }

    private func updateFeaturedSectionsAfterSync() {

        #if FEATURED_TAB_ENABLED
        storage
            .featuredSectionsObservable
            .filter { !$0.isEmpty }
            .subscribeOn(MainScheduler.instance)
            .take(1)
            .subscribe(onNext: { [weak self] sections in
                self?.featuredController.sections = sections.map { FeaturedSectionViewModel(section: $0) }
            }).disposed(by: disposeBag)
        #endif
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

        _ = NotificationCenter.default.addObserver(forName: .SyncEngineDidSyncFeaturedSections, object: nil, queue: .main) { note in
            if let error = note.object as? Error {
                NSApp.presentError(error)
            } else {
                self.updateFeaturedSectionsAfterSync()
            }
        }

        _ = NotificationCenter.default.addObserver(forName: .WWDCEnvironmentDidChange, object: nil, queue: .main) { _ in
            self.refresh(nil)
        }

        refresh(nil)
        updateListsAfterSync()
        updateFeaturedSectionsAfterSync()

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

    @discardableResult func receiveNotification(with userInfo: [String: Any]) -> Bool {
        let userDataSyncEngineHandled: Bool

        #if ICLOUD
        userDataSyncEngineHandled = syncEngine.userDataSyncEngine.processSubscriptionNotification(with: userInfo)
        #else
        userDataSyncEngineHandled = false
        #endif

        return userDataSyncEngineHandled ||
            liveObserver.processSubscriptionNotification(with: userInfo) ||
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
        Preferences.shared.selectedScheduleItemIdentifier = selectedScheduleItemValue?.identifier
        Preferences.shared.selectedVideoItemIdentifier = selectedSessionValue?.identifier
        Preferences.shared.filtersState = searchCoordinator.currentFiltersState()
    }

    private func restoreApplicationState() {

        let activeTab = Preferences.shared.activeTab
        tabController.activeTab = activeTab

        if let identifier = Preferences.shared.selectedScheduleItemIdentifier {
            scheduleController.listViewController.select(session: SessionIdentifier(identifier))
        }

        if let identifier = Preferences.shared.selectedVideoItemIdentifier {
            videosController.listViewController.select(session: SessionIdentifier(identifier))
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
            scheduleController.listViewController.select(session: SessionIdentifier(link.sessionIdentifier))
        } else {
            tabController.activeTab = .videos
            videosController.listViewController.select(session: SessionIdentifier(link.sessionIdentifier))
        }
    }

    // MARK: - Preferences

    private lazy var preferencesCoordinator = PreferencesCoordinator()

    func showAccountPreferences() {
        preferencesCoordinator.show(in: .account)
    }

    func showPreferences(_ sender: Any?) {
        #if ICLOUD
        preferencesCoordinator.userDataSyncEngine = syncEngine.userDataSyncEngine
        #endif

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

    func showFeatured() {
        #if FEATURED_TAB_ENABLED
        tabController.activeTab = .featured
        #endif
    }

    func showSchedule() {
        tabController.activeTab = .schedule
    }

    func showVideos() {
        tabController.activeTab = .videos
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
