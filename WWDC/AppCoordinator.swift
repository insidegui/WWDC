//
//  AppCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import Combine
import ConfCore
import PlayerUI
import os.log
import AVFoundation

final class AppCoordinator {

    let log = OSLog(subsystem: "WWDC", category: "AppCoordinator")
    private lazy var cancellables = Set<AnyCancellable>()

    var liveObserver: LiveObserver

    var storage: Storage
    var syncEngine: SyncEngine

    var windowController: MainWindowController
    var tabController: WWDCTabViewController<MainWindowTab>

    var featuredController: FeaturedContentViewController
    var scheduleController: ScheduleContainerViewController
    var videosController: SessionsSplitViewController

    var currentPlayerController: VideoPlayerViewController?

    var currentActivity: NSUserActivity?

    var activeTab: MainWindowTab = .schedule

    /// The tab that "owns" the current player (the one that was active when the "play" button was pressed)
    var playerOwnerTab: MainWindowTab?

    /// The session that "owns" the current player (the one that was selected on the active tab when "play" was pressed)
    @Published
    var playerOwnerSessionIdentifier: String?

    /// Whether we're currently in the middle of a player context transition
    var isTransitioningPlayerContext = false

    /// Whether we were playing the video when a clip sharing session begin, to restore state later.
    var wasPlayingWhenClipSharingBegan = false

    init(windowController: MainWindowController, storage: Storage, syncEngine: SyncEngine) {
        self.storage = storage
        self.syncEngine = syncEngine

        DownloadManager.shared.start(with: storage)

        liveObserver = LiveObserver(dateProvider: today, storage: storage, syncEngine: syncEngine)

        // Primary UI Initialization

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

        self.windowController = windowController

        restoreApplicationState()

        setupBindings()
        setupDelegation()

        _ = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in self.saveApplicationState() }
        _ = NotificationCenter.default.addObserver(forName: .RefreshPeriodicallyPreferenceDidChange, object: nil, queue: nil, using: { _  in self.resetAutorefreshTimer() })
        _ = NotificationCenter.default.addObserver(forName: .PreferredTranscriptLanguageDidChange, object: nil, queue: .main, using: { self.preferredTranscriptLanguageDidChange($0) })

        NSApp.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        
        let buttonsController = TitleBarButtonsViewController(
            downloadManager: DownloadManager.shared,
            storage: storage
        )
        windowController.titleBarViewController.statusViewController = buttonsController
        
        buttonsController.handleSharePlayClicked = { [weak self] in
            DispatchQueue.main.async { self?.startSharePlay() }
        }
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
    var selectedSession: some Publisher<SessionViewModel?, Never> {
        return videosController.listViewController.$selectedSession
    }

    /// The session that is currently selected on the schedule tab (observable)
    var selectedScheduleItem: some Publisher<SessionViewModel?, Never> {
        return scheduleController.splitViewController.listViewController.$selectedSession
    }

    /// The session that is currently selected on the videos tab
    var selectedSessionValue: SessionViewModel? {
        return videosController.listViewController.selectedSession
    }

    /// The session that is currently selected on the schedule tab
    var selectedScheduleItemValue: SessionViewModel? {
        return scheduleController.splitViewController.listViewController.selectedSession
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
        tabController
            .$activeTabVar
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] activeTab in

            self?.activeTab = activeTab

            self?.updateSelectedViewModelRegardlessOfTab()
        }).store(in: &cancellables)

        func bind<P: Publisher>(session: P, to detailsController: SessionDetailsViewController) where P.Output == SessionViewModel?, P.Failure == Never {

            session.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] viewModel in
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.35

                    detailsController.viewModel = viewModel
                    self?.updateSelectedViewModelRegardlessOfTab()
                })

            }).store(in: &cancellables)
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

    typealias StartUpDependencies = (tracks: Results<Track>, events: Results<Event>, foci: Results<Focus>, scheduleSections: Results<ScheduleSection>, featuredSections: Results<FeaturedSection>)

    private func doUpdateLists() {

        // Initial app launch waits for all of these things to be loaded before dismissing the primary loading spinner
        // It may, however, delay the presentation of content on tabs that already have everything they need

        let startupDependencies: AnyPublisher<StartUpDependencies, Error> = Publishers.CombineLatest4(
            storage.tracksObservable,
            storage.eventsObservable,
            storage.focusesObservable,
            storage.scheduleObservable
        ).combineLatest(storage.featuredSectionsObservable) { firstTuple, valueToAdd in
            return (firstTuple.0, firstTuple.1, firstTuple.2, firstTuple.3, valueToAdd)
        }
            .eraseToAnyPublisher()

        let type: AnyPublisher<StartUpDependencies, Error> = startupDependencies
            .filter {
                !$0.0.isEmpty && !$0.1.isEmpty && !$0.2.isEmpty && !$0.4.isEmpty
            }
            .prefix(1)
            .eraseToAnyPublisher()
        type
            .catch { _ in
//                Swift.print($0)
                return Empty<StartUpDependencies, Never>()
            }
            .sink(receiveValue: { [weak self] tracks, _, _, sections, _ in
                guard let self = self else { return }

                self.tabController.hideLoading()
                self.searchCoordinator.configureFilters()

                self.videosController.listViewController.sessionRowProvider = VideosSessionRowProvider(tracks: tracks)

                self.scheduleController.splitViewController.listViewController.sessionRowProvider = ScheduleSessionRowProvider(scheduleSections: sections)
                self.scrollToTodayIfWWDC()
            }).store(in: &cancellables)

        bindScheduleAvailability()

        liveObserver.start()

        DispatchQueue.main.async { self.configureSharePlayIfSupported() }
    }

    private func bindScheduleAvailability() {
//        storage.eventHeroObservable.map({ $0 != nil })
//                                  .bind(to: scheduleController.showHeroView)
//                                  .store(in: &cancellables)
//
//        storage.eventHeroObservable.bind(to: scheduleController.heroController.hero)
//                                   .store(in: &cancellables)
    }

    private func updateFeaturedSectionsAfterSync() {

        storage
            .featuredSectionsObservable
            .filter { !$0.isEmpty }
            .prefix(1)
            .catch { _ in
//                Swift.print($0)
                return Empty<Results<FeaturedSection>, Never>()
            }
            .receive(on: DispatchQueue.main)

            .sink(receiveValue: { [weak self] sections in
                self?.featuredController.sections = sections.map { FeaturedSectionViewModel(section: $0) }
            })
            .store(in: &cancellables)
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
                case .http:
                    break
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
        userDataSyncEngineHandled = syncEngine.userDataSyncEngine?.processSubscriptionNotification(with: userInfo) == true
        #else
        userDataSyncEngineHandled = false
        #endif

        return userDataSyncEngineHandled ||
            liveObserver.processSubscriptionNotification(with: userInfo) ||
            RemoteEnvironment.shared.processSubscriptionNotification(with: userInfo)
    }

    // MARK: - Now playing info

    private var nowPlayingInfoBag: Set<AnyCancellable> = []

    private func observeNowPlayingInfo() {
        nowPlayingInfoBag = []

//        currentPlaybackViewModel?.nowPlayingInfo.asObservable().subscribe(onNext: { [weak self] _ in
//            self?.publishNowPlayingInfo()
//        }).disposed(by: nowPlayingInfoBag)
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

    func handle(link: DeepLink) {

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
    
    // MARK: - SharePlay
    
    private var sharePlayConfigured = false

    func configureSharePlayIfSupported() {
        let log = OSLog(subsystem: SharePlayManager.subsystemName, category: String(describing: AppCoordinator.self))
        
        guard !sharePlayConfigured else { return }
        sharePlayConfigured = true
        
        SharePlayManager.shared.$state.sink { [weak self] state in
            guard let self = self else { return }
            
            guard case .session(let session) = state else { return }
            
            self.currentPlayerController?.player?.playbackCoordinator.coordinateWithSession(session)
        }.store(in: &cancellables)
        
        SharePlayManager.shared.$currentActivity.sink { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            
            guard let wwdcSession = self.storage.session(with: activity.sessionID) else {
                os_log("Couldn't find the session with ID %{public}@", log: log, type: .error, activity.sessionID)
                return
            }
            
            guard let viewModel = SessionViewModel(session: wwdcSession) else {
                os_log("Couldn't create the view model for session %{public}@", log: log, type: .error, activity.sessionID)
                return
            }
            
            self.selectSessionOnAppropriateTab(with: viewModel)
            
            DispatchQueue.main.async {
                self.videosController.detailViewController.shelfController.play(nil)
            }
        }.store(in: &cancellables)
        
        SharePlayManager.shared.startObservingState()
    }
    
    func activePlayerDidChange(to newPlayer: AVPlayer?) {
        os_log("%{public}@", log: log, type: .debug, #function)
        
        guard case .session(let session) = SharePlayManager.shared.state else { return }
        
        os_log("Attaching new player to active SharePlay session", log: self.log, type: .debug)
        
        newPlayer?.playbackCoordinator.coordinateWithSession(session)
    }

    func startSharePlay() {
        if case .session = SharePlayManager.shared.state {
            let alert = NSAlert()
            alert.messageText = "Leave SharePlay?"
            alert.informativeText = "Are you sure you'd like to leave this SharePlay session?"
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Leave")
            
            if alert.runModal() == .alertSecondButtonReturn {
                SharePlayManager.shared.leaveActivity()
            }
            
            return
        }
        
        guard let viewModel = selectedSessionValue else {
            let alert = NSAlert()
            alert.messageText = "Select a Session"
            alert.informativeText = "Please select the session you'd like to watch together, then start SharePlay."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        SharePlayManager.shared.startActivity(for: viewModel.session)
    }

}
