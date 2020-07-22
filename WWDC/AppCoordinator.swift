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
import os.log

final class AppCoordinator {

    let log = OSLog(subsystem: "WWDC", category: "AppCoordinator")
    private let disposeBag = DisposeBag()

    var liveObserver: LiveObserver

    var storage: Storage
    var syncEngine: SyncEngine

    var windowController: MainWindowController
    var tabController: WWDCTabViewController<MainWindowTab>

    var featuredController: FeaturedContentViewController
    var scheduleController: ScheduleContainerViewController
    var videosController: SessionsSplitViewController
    var communityController: CommunityViewController

    var currentPlayerController: VideoPlayerViewController?

    var currentActivity: NSUserActivity?

    var activeTab: MainWindowTab = .schedule

    /// The tab that "owns" the current player (the one that was active when the "play" button was pressed)
    var playerOwnerTab: MainWindowTab?

    /// The session that "owns" the current player (the one that was selected on the active tab when "play" was pressed)
    var playerOwnerSessionIdentifier: String? {
        didSet { rxPlayerOwnerSessionIdentifier.onNext(playerOwnerSessionIdentifier) }
    }
    var rxPlayerOwnerSessionIdentifier = BehaviorSubject<String?>(value: nil)

    /// Whether we're currently in the middle of a player context transition
    var isTransitioningPlayerContext = false

    /// Whether we were playing the video when a clip sharing session begin, to restore state later.
    var wasPlayingWhenClipSharingBegan = false

    init(windowController: MainWindowController, storage: Storage, syncEngine: SyncEngine) {
        self.storage = storage
        self.syncEngine = syncEngine

        DownloadManager.shared.start(with: storage)

        windowController.titleBarViewController.statusViewController = DownloadsStatusViewController(downloadManager: DownloadManager.shared, storage: storage)

        liveObserver = LiveObserver(dateProvider: today, storage: storage, syncEngine: syncEngine)

        // Primary UI Intialization

        tabController = WWDCTabViewController(windowController: windowController)

        // Featured
        featuredController = FeaturedContentViewController()
        featuredController.identifier = NSUserInterfaceItemIdentifier(rawValue: "Featured")
        let featuredItem = NSTabViewItem(viewController: featuredController)
        featuredItem.label = "Featured"
        tabController.addTabViewItem(featuredItem)

        // Schedule
        scheduleController = ScheduleContainerViewController(windowController: windowController, listStyle: .schedule)
        scheduleController.identifier = NSUserInterfaceItemIdentifier(rawValue: "Schedule")
        scheduleController.splitViewController.splitView.identifier = NSUserInterfaceItemIdentifier(rawValue: "ScheduleSplitView")
        scheduleController.splitViewController.splitView.autosaveName = "ScheduleSplitView"
        let scheduleItem = NSTabViewItem(viewController: scheduleController)
        scheduleItem.label = "Schedule"
        scheduleItem.initialFirstResponder = scheduleController.splitViewController.listViewController.tableView
        tabController.addTabViewItem(scheduleItem)

        // Videos
        videosController = SessionsSplitViewController(windowController: windowController, listStyle: .videos)
        videosController.identifier = NSUserInterfaceItemIdentifier(rawValue: "Videos")
        videosController.splitView.identifier = NSUserInterfaceItemIdentifier(rawValue: "VideosSplitView")
        videosController.splitView.autosaveName = "VideosSplitView"
        let videosItem = NSTabViewItem(viewController: videosController)
        videosItem.label = "Videos"
        videosItem.initialFirstResponder = videosController.listViewController.tableView
        tabController.addTabViewItem(videosItem)

        // Community
        communityController = CommunityViewController(syncEngine: syncEngine)
        communityController.identifier = NSUserInterfaceItemIdentifier(rawValue: "Community")
        let communityItem = NSTabViewItem(viewController: communityController)
        communityItem.label = "Community"
        tabController.addTabViewItem(communityItem)

        self.windowController = windowController

        restoreApplicationState()

        setupBindings()
        setupDelegation()

        _ = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in self.saveApplicationState() }
        _ = NotificationCenter.default.addObserver(forName: .RefreshPeriodicallyPreferenceDidChange, object: nil, queue: nil, using: { _  in self.resetAutorefreshTimer() })
        _ = NotificationCenter.default.addObserver(forName: .PreferredTranscriptLanguageDidChange, object: nil, queue: .main, using: { self.preferredTranscriptLanguageDidChange($0) })

        NSApp.isAutomaticCustomizeTouchBarMenuItemEnabled = true
    }

    /// The list controller for the active tab
    var currentListController: SessionsTableViewController? {
        switch activeTab {
        case .schedule:
            return scheduleController.splitViewController.listViewController
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
        return scheduleController.splitViewController.listViewController.selectedSession.asObservable()
    }

    /// The session that is currently selected on the videos tab
    var selectedSessionValue: SessionViewModel? {
        return videosController.listViewController.selectedSession.value
    }

    /// The session that is currently selected on the schedule tab
    var selectedScheduleItemValue: SessionViewModel? {
        return scheduleController.splitViewController.listViewController.selectedSession.value
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

        bind(session: selectedScheduleItem, to: scheduleController.splitViewController.detailViewController)
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

        } else if scheduleController.splitViewController.listViewController.canDisplay(session: viewModel) {
            scheduleController.splitViewController.listViewController.select(session: viewModel)
            tabController.activeTab = .schedule
        }
    }

    private func setupDelegation() {
        let videoDetail = videosController.detailViewController

        videoDetail.shelfController.delegate = self
        videoDetail.summaryController.actionsViewController.delegate = self
        videoDetail.summaryController.relatedSessionsViewController.delegate = self

        let scheduleDetail = scheduleController.splitViewController.detailViewController

        scheduleDetail.shelfController.delegate = self
        scheduleDetail.summaryController.actionsViewController.delegate = self
        scheduleDetail.summaryController.relatedSessionsViewController.delegate = self

        videosController.listViewController.delegate = self
        scheduleController.splitViewController.listViewController.delegate = self

        featuredController.delegate = self
    }

    private func updateListsAfterSync() {
        doUpdateLists()

        DownloadManager.shared.syncWithFileSystem()
    }

    private func doUpdateLists() {

        // Initial app launch waits for all of these things to be loaded before dismissing the primary loading spinner
        // It may, however, delay the presentation of content on tabs that already have everything they need

        let startupDependencies = Observable.combineLatest(storage.tracksObservable,
                                                          storage.eventsObservable,
                                                          storage.focusesObservable,
                                                          storage.scheduleObservable,
                                                          storage.featuredSectionsObservable)

        startupDependencies
            .filter {
                !$0.0.isEmpty && !$0.1.isEmpty && !$0.2.isEmpty && !$0.4.isEmpty
            }
            .take(1)
            .subscribe(onNext: { [weak self] tracks, _, _, sections, _ in
                guard let self = self else { return }

                self.tabController.hideLoading()
                self.searchCoordinator.configureFilters()

                self.videosController.listViewController.sessionRowProvider = VideosSessionRowProvider(tracks: tracks)

                self.scheduleController.splitViewController.listViewController.sessionRowProvider = ScheduleSessionRowProvider(scheduleSections: sections)
                self.scrollToTodayIfWWDC()
            }).disposed(by: disposeBag)

        bindScheduleAvailability()

        liveObserver.start()
    }

    private func bindScheduleAvailability() {
        // Show schedule unavailable view if there's no schedule

        storage.scheduleObservable.map({ $0.isEmpty })
                                  .bind(to: scheduleController.showHeroView)
                                  .disposed(by: disposeBag)

        storage.eventHeroObservable.bind(to: scheduleController.heroController.hero)
                                   .disposed(by: disposeBag)
    }

    private func updateFeaturedSectionsAfterSync() {

        storage
            .featuredSectionsObservable
            .filter { !$0.isEmpty }
            .subscribeOn(MainScheduler.instance)
            .take(1)
            .subscribe(onNext: { [weak self] sections in
                self?.featuredController.sections = sections.map { FeaturedSectionViewModel(section: $0) }
            }).disposed(by: disposeBag)
    }

    private lazy var searchCoordinator: SearchCoordinator = {
        return SearchCoordinator(self.storage,
                                 sessionsController: self.scheduleController.splitViewController.listViewController,
                                 videosController: self.videosController.listViewController,
                                 restorationFiltersState: Preferences.shared.filtersState)
    }()

    func startup() {
        RemoteEnvironment.shared.start()

        ContributorsFetcher.shared.load()

        windowController.contentViewController = tabController
        windowController.showWindow(self)

        if storage.isEmpty {
            tabController.showLoading()
        }

        func checkSyncEngineOperationSucceededAndShowError(note: Notification) -> Bool {
            if let error = note.object as? APIError {
                switch error {
                case .adapter, .unknown:
                    WWDCAlert.show(with: error)
                case .http:()
                }
            } else if let error = note.object as? Error {
                WWDCAlert.show(with: error)
            } else {
                return true
            }

            return false
        }

        _ = NotificationCenter.default.addObserver(forName: .SyncEngineDidSyncSessionsAndSchedule, object: nil, queue: .main) { note in
            guard checkSyncEngineOperationSucceededAndShowError(note: note) else { return }
            self.updateListsAfterSync()
        }

        _ = NotificationCenter.default.addObserver(forName: .SyncEngineDidSyncFeaturedSections, object: nil, queue: .main) { note in
            guard checkSyncEngineOperationSucceededAndShowError(note: note) else { return }
            self.updateFeaturedSectionsAfterSync()
        }

        _ = NotificationCenter.default.addObserver(forName: .WWDCEnvironmentDidChange, object: nil, queue: .main) { _ in
            self.refresh(nil)
        }

        refresh(nil)
        updateListsAfterSync()
        updateFeaturedSectionsAfterSync()

        if Arguments.showPreferences {
            showPreferences(nil)
        }
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
            scheduleController.splitViewController.listViewController.select(session: SessionIdentifier(identifier))
        }

        if let identifier = Preferences.shared.selectedVideoItemIdentifier {
            videosController.listViewController.select(session: SessionIdentifier(identifier))
        }
    }

    private func scrollToTodayIfWWDC() {
        guard liveObserver.isWWDCWeek else { return }

        scheduleController.splitViewController.listViewController.scrollToToday()
    }

    // MARK: - Deep linking

    func handle(link: DeepLink, deferIfNeeded: Bool) {

        if link.isForCurrentYear {
            tabController.activeTab = .schedule
            scheduleController.splitViewController.listViewController.select(session: SessionIdentifier(link.sessionIdentifier))
        } else {
            tabController.activeTab = .videos
            videosController.listViewController.select(session: SessionIdentifier(link.sessionIdentifier))
        }
    }

    // MARK: - Preferences

    private lazy var preferencesCoordinator: PreferencesCoordinator = {
        PreferencesCoordinator(syncEngine: syncEngine)
    }()

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
        tabController.activeTab = .featured
    }

    func showSchedule() {
        tabController.activeTab = .schedule
    }

    func showVideos() {
        tabController.activeTab = .videos
    }

    func showCommunity() {
        tabController.activeTab = .community
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
            self.syncEngine.syncConfiguration()

            self.syncEngine.syncContent()

            self.syncEngine.syncCommunityContent()

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

    // MARK: - Language preference

    private func preferredTranscriptLanguageDidChange(_ note: Notification) {
        guard let code = note.object as? String else { return }

        syncEngine.transcriptLanguage = code
    }

}
