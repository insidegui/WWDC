//
//  NewAppCoordinator.swift
//  WWDC
//
//  Created by luca on 30.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AVFoundation
import Cocoa
import Combine
import ConfCore
import OSLog
import PlayerUI
import RealmSwift
import SwiftUI

@available(macOS 26.0, *)
extension EnvironmentValues {
    var coordinator: NewAppCoordinator? {
        self[KeyCoordinator.self]
    }

    fileprivate struct KeyCoordinator: SwiftUICore.EnvironmentKey {
        static var defaultValue: NewAppCoordinator? {
            (NSApp.delegate as? AppDelegate)?.coordinator as? NewAppCoordinator
        }
    }
}

@available(macOS 26.0, *)
extension Observable {
    var coordinator: NewAppCoordinator? {
        EnvironmentValues.KeyCoordinator.defaultValue
    }
}

@available(macOS 26.0, *)
final class NewAppCoordinator: WWDCCoordinator {
    nonisolated static let log = makeLogger()
    nonisolated static let signposter: OSSignposter = makeSignposter()

    private lazy var cancellables = Set<AnyCancellable>()

    var liveObserver: LiveObserver

    var storage: Storage
    var syncEngine: SyncEngine

    // - Top level controllers
    var windowController: WWDCWindowControllerObject
    var tabController: ReplaceableSplitViewController
    var searchCoordinator: NewGlobalSearchCoordinator

    // - The 3 tabs
    let exploreViewModel: NewExploreViewModel
    let scheduleTable: NewSessionsTableViewController
    let videosTable: NewSessionsTableViewController
    var currentShelfViewController: ShelfViewController?

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

    /// The list controller for the active tab
    var currentTable: NewSessionsTableViewController? {
        switch activeTab {
        case .explore:
            return nil
        case .schedule:
            return scheduleTable
        case .videos:
            return videosTable
        }
    }

    var exploreTabLiveSession: AnyPublisher<SessionViewModel?, Never> {
        let liveInstances = storage.realm.objects(SessionInstance.self)
            .filter("rawSessionType == 'Special Event' AND isCurrentlyLive == true")
            .sorted(byKeyPath: "startTime", ascending: false)

        return liveInstances.collectionPublisher
            .map { $0.toArray().first?.session }
            .map { SessionViewModel(session: $0, instance: $0?.instances.first, track: nil, style: .schedule) }
            .replaceErrorWithEmpty()
            .eraseToAnyPublisher()
    }

    /// The session that is currently selected on the videos tab (observable)
    var videosSelectedSessionViewModel: SessionViewModel? { videosTable.selectedSession }

    /// The session that is currently selected on the schedule tab (observable)
    var scheduleSelectedSessionViewModel: SessionViewModel? { scheduleTable.selectedSession }

    /// The selected session's view model, regardless of which tab it is selected in
    var activeTabSelectedSessionViewModel: SessionViewModel? { detailViewModel.session }
    var detailViewModel: SessionItemViewModel

    /// The viewModel for the current playback session
    var currentPlaybackViewModel: PlaybackViewModel? {
        didSet {
            observeNowPlayingInfo()
        }
    }

    private lazy var downloadMonitor = DownloadedContentMonitor()

    @MainActor
    init(windowController: WWDCWindowControllerObject, storage: Storage, syncEngine: SyncEngine) {
        let signpostState = Self.signposter.beginInterval("initialization", id: Self.signposter.makeSignpostID(), "begin init")
        self.storage = storage
        self.syncEngine = syncEngine

        let searchCoordinator = NewGlobalSearchCoordinator(
            self.storage,
            restorationFiltersState: Preferences.shared.filtersState
        )
        self.searchCoordinator = searchCoordinator

        liveObserver = LiveObserver(dateProvider: today, storage: storage, syncEngine: syncEngine)

        // Primary UI Initialization

        // Explore
        let provider = ExploreTabProvider(storage: storage)
        exploreViewModel = NewExploreViewModel(provider: provider)

        videosTable = NewSessionsTableViewController(
            searchCoordinator: VideosSearchCoordinator(
                storage,
                tabState: GlobalSearchTabState(
                    additionalPredicates: [Session.videoPredicate],
                    filterPredicate: .init(predicate: nil, changeReason: .initialValue)
                )
            ),
            rowProvider: VideosSessionRowProvider(
                tracks: storage.tracks,
                filterPredicate: searchCoordinator.$videosFilterPredicate,
                playingSessionIdentifier: _playerOwnerSessionIdentifier.projectedValue
            ),
            initialSelection: Preferences.shared.selectedVideoItemIdentifier.map(SessionIdentifier.init)
        )
        scheduleTable = NewSessionsTableViewController(
            searchCoordinator: ScheduleSearchCoordinator(
                storage,
                tabState: GlobalSearchTabState(
                    additionalPredicates: [
                        NSPredicate(format: "ANY session.event.isCurrent == true"),
                        NSPredicate(format: "session.instances.@count > 0")
                    ],
                    filterPredicate: .init(predicate: nil, changeReason: .initialValue)
                )
            ),
            rowProvider: ScheduleSessionRowProvider(
                scheduleSections: storage.scheduleSections,
                filterPredicate: searchCoordinator.$scheduleFilterPredicate,
                playingSessionIdentifier: _playerOwnerSessionIdentifier.projectedValue
            ),
            initialSelection: Preferences.shared.selectedScheduleItemIdentifier.map(SessionIdentifier.init)
        )
        detailViewModel = .init()
        tabController = ReplaceableSplitViewController(windowController: windowController, exploreViewModel: exploreViewModel, scheduleTable: scheduleTable, videosTable: videosTable, detailViewModel: detailViewModel)

        _playerOwnerSessionIdentifier = .init(initialValue: nil)
        self.windowController = windowController

        NSApp.isAutomaticCustomizeTouchBarMenuItemEnabled = true

        let buttonsController = TitleBarButtonsViewController(
            downloadManager: .shared,
            storage: storage
        )
        windowController.titleBarViewController.statusViewController = buttonsController

        buttonsController.handleSharePlayClicked = { [weak self] in
            DispatchQueue.main.async { self?.startSharePlay() }
        }

        MediaDownloadManager.shared.activate()
        downloadMonitor.activate(with: storage)

        Self.signposter.endInterval("initialization", signpostState, "end init")
    }

    // MARK: - Start up

    @MainActor
    func startup() {
        setupBindings()

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification).sink { _ in
            self.saveApplicationState()
        }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .RefreshPeriodicallyPreferenceDidChange).sink { _ in
            self.resetAutorefreshTimer()
        }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .PreferredTranscriptLanguageDidChange).receive(on: DispatchQueue.main).sink {
            self.preferredTranscriptLanguageDidChange($0)
        }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .SyncEngineDidSyncSessionsAndSchedule).receive(on: DispatchQueue.main).sink { [weak self] note in
            guard let self else { return }

            guard self.checkSyncEngineOperationSucceededAndShowError(note: note) == true else { return }

            self.downloadMonitor.syncWithFileSystem()
        }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .WWDCEnvironmentDidChange).receive(on: DispatchQueue.main).sink { _ in
            self.refresh(nil)
        }.store(in: &cancellables)

        liveObserver.start()

        DispatchQueue.main.async { self.configureSharePlayIfSupported() }

        refresh(nil)
        windowController.contentViewController = tabController
        windowController.showWindow(self)
//        tabController.showLoading()
        tabController.setActiveTab(Preferences.shared.activeTab)

        [videosTable, scheduleTable].forEach {
            $0.sessionRowProvider.startup()
        }
        if Arguments.showPreferences {
            showPreferences(nil)
        }
    }

    private func setupBindings() {
        Publishers.CombineLatest3(
            tabController.activeTabPublisher(for: MainWindowTab.self),
            videosTable.$selectedSession,
            scheduleTable.$selectedSession
        ).receive(on: DispatchQueue.main)
            .sink { [weak self] activeTab, newVideoModel, newScheduleModel in
                guard let self else { return }
                self.activeTab = activeTab

                switch activeTab {
                case .schedule:
                    detailViewModel.session = newScheduleModel
                case .videos:
                    detailViewModel.session = newVideoModel
                default:
                    detailViewModel.session = nil
                }

                updateShelfBasedOnSelectionChange()
                updateCurrentActivity(with: activeTabSelectedSessionViewModel)
            }
            .store(in: &cancellables)
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

    func selectSessionOnAppropriateTab(with viewModel: SessionViewModel) {
        if currentTable?.canDisplay(session: viewModel) == true {
            currentTable?.select(session: viewModel, removingFiltersIfNeeded: true)
            return
        }
        // always to videos
        videosTable.select(session: viewModel, removingFiltersIfNeeded: true)
        tabController.setActiveTab(MainWindowTab.videos)
    }

    @discardableResult func receiveNotification(with userInfo: [String: Any]) -> Bool {
        let userDataSyncEngineHandled: Bool

        #if ICLOUD
        userDataSyncEngineHandled = syncEngine.userDataSyncEngine?.processSubscriptionNotification(with: userInfo) == true
        #else
        userDataSyncEngineHandled = false
        #endif

        return userDataSyncEngineHandled ||
            liveObserver.processSubscriptionNotification(with: userInfo)
    }

    // MARK: - Now playing info

    private var nowPlayingInfoBag: Set<AnyCancellable> = []

    private func observeNowPlayingInfo() {
        nowPlayingInfoBag = []

        currentPlaybackViewModel?.$nowPlayingInfo.sink(receiveValue: { [weak self] _ in
            self?.publishNowPlayingInfo()
        }).store(in: &nowPlayingInfoBag)
    }

    // MARK: - State restoration

    private func saveApplicationState() {
        Preferences.shared.activeTab = activeTab
        Preferences.shared.selectedScheduleItemIdentifier = scheduleSelectedSessionViewModel?.identifier
        Preferences.shared.selectedVideoItemIdentifier = videosSelectedSessionViewModel?.identifier
        Preferences.shared.filtersState = searchCoordinator.restorationSnapshot()
    }

    // MARK: - Deep linking

    func handle(link: DeepLink) {
        if link.isForCurrentYear {
            tabController.setActiveTab(MainWindowTab.schedule)
//            scheduleListController.select(session: link)
        } else {
            tabController.setActiveTab(MainWindowTab.videos)
//            videosListController.select(session: link)
        }
    }

    func applyFilter(state: WWDCFiltersState) {
        tabController.setActiveTab(MainWindowTab.videos)

        DispatchQueue.main.async {
            self.searchCoordinator.apply(state)
        }
    }

    // MARK: - Preferences

    private lazy var preferencesCoordinator: PreferencesCoordinator = .init(syncEngine: syncEngine)

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

        ContributorsFetcher.shared.load()

        return aboutWC
    }()

    func showAboutWindow() {
        aboutWindowController.showWindow(nil)
    }

    func showExplore() {
        tabController.setActiveTab(MainWindowTab.explore)
    }

    func showSchedule() {
        tabController.setActiveTab(MainWindowTab.schedule)
    }

    func showVideos() {
        tabController.setActiveTab(MainWindowTab.videos)
    }

    // MARK: - Refresh

    /// Used to prevent the refresh system from being spammed. Resetting
    /// NSBackgroundActivitySchedule can result in the scheduled activity happening immediately
    /// especially if the `interval` is sufficiently low.
    private var lastRefresh = Date.distantPast

    func refresh(_ sender: Any?) {
        guard !NSApp.isPreview else { return }

        let now = Date()
        guard now.timeIntervalSince(lastRefresh) > 5 else { return }
        lastRefresh = now

        DispatchQueue.main.async {
            self.syncEngine.syncConfiguration()

            self.syncEngine.syncContent()

            self.liveObserver.refresh()

            if self.autorefreshActivity == nil
                || (sender as? NSBackgroundActivityScheduler) !== self.autorefreshActivity
            {
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
            DispatchQueue.main.async {
                self?.refresh(self?.autorefreshActivity)
            }
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
        let log = ConfCore.makeLogger(subsystem: SharePlayManager.defaultLoggerConfig().subsystem, category: String(describing: AppCoordinator.self))

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
                log.error("Couldn't find the session with ID \(activity.sessionID, privacy: .public)")
                return
            }

            guard let viewModel = SessionViewModel(session: wwdcSession) else {
                log.error("Couldn't create the view model for session \(activity.sessionID, privacy: .public)")
                return
            }

            self.selectSessionOnAppropriateTab(with: viewModel)

            DispatchQueue.main.async {
//                self.videosDetailController.shelfController.play(nil)
            }
        }.store(in: &cancellables)

        SharePlayManager.shared.startObservingState()
    }

    func activePlayerDidChange(to newPlayer: AVPlayer?) {
        log.debug("\(#function, privacy: .public)")

        guard case .session(let session) = SharePlayManager.shared.state else { return }

        log.debug("Attaching new player to active SharePlay session")

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

        guard let viewModel = videosSelectedSessionViewModel else {
            let alert = NSAlert()
            alert.messageText = "Select a Session"
            alert.informativeText = "Please select the session you'd like to watch together, then start SharePlay."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        SharePlayManager.shared.startActivity(for: viewModel.session)
    }

    // MARK: - Shelf

    func shelf(for tab: MainWindowTab) -> ShelfViewController? {
        currentShelfViewController
    }

    func select(session: any SessionIdentifiable, removingFiltersIfNeeded: Bool) {
        currentTable?.select(session: session, removingFiltersIfNeeded: removingFiltersIfNeeded)
    }

    func showClipUI() {}
}
