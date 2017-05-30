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
    var playerOwnerTab: MainWindowTab? = nil
    
    /// The session that "owns" the current player (the one that was selected on the active tab when "play" was pressed)
    var playerOwnerSessionIdentifier: String? = nil
    
    /// Whether playback can be restored to the previous context when exiting PiP mode (go back to tab/session)
    var canRestorePlaybackContext = false
    
    /// Whether we're currently in the middle of a player context transition
    var isTransitioningPlayerContext = false
    
    init(windowController: MainWindowController) {
        let filePath = PathUtil.appSupportPath + "/ConfCore.realm"
        
        var realmConfig = Realm.Configuration(fileURL: URL(fileURLWithPath: filePath))
        realmConfig.schemaVersion = Constants.coreSchemaVersion
        
        let client = AppleAPIClient(environment: .current)
        
        do {
            self.storage = try Storage(realmConfig)
            
            self.syncEngine = SyncEngine(storage: storage, client: client)
        } catch {
            fatalError("Realm initialization error: \(error)")
        }
        
        DownloadManager.shared.start(with: storage)
        
        self.tabController = WWDCTabViewController()
        
        // Schedule
        self.scheduleController = SessionsSplitViewController(listStyle: .schedule)
        scheduleController.identifier = "Schedule"
        let scheduleItem = NSTabViewItem(viewController: scheduleController)
        scheduleItem.label = "Schedule"
        self.tabController.addTabViewItem(scheduleItem)
        
        // Videos
        self.videosController = SessionsSplitViewController(listStyle: .videos)
        videosController.identifier = "Videos"
        let videosItem = NSTabViewItem(viewController: videosController)
        videosItem.label = "Videos"
        self.tabController.addTabViewItem(videosItem)
        
        self.windowController = windowController
        
        self.liveObserver = LiveObserver(dateProvider: Today, storage: storage)
        
        setupBindings()
        setupDelegation()
        
        NotificationCenter.default.addObserver(forName: .WWDCTabViewControllerDidFinishLoading, object: nil, queue: nil) { _ in self.restoreApplicationState() }
        NotificationCenter.default.addObserver(forName: .NSApplicationDidFinishLaunching, object: nil, queue: nil) { _ in self.startup() }
        NotificationCenter.default.addObserver(forName: .NSApplicationWillTerminate, object: nil, queue: nil) { _ in self.saveApplicationState() }
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
    var currentPlaybackViewModel: PlaybackViewModel?
    
    private func setupBindings() {
        tabController.rxActiveTab.subscribe(onNext: { [weak self] activeTab in
            self?.activeTab = activeTab
            
            self?.updateSelectedViewModelRegardlessOfTab()
        }).addDisposableTo(self.disposeBag)
        
        selectedSession.subscribeOn(MainScheduler.instance).subscribe(onNext: { [weak self] viewModel in
            self?.videosController.detailViewController.viewModel = viewModel
            self?.updateSelectedViewModelRegardlessOfTab()
        }).addDisposableTo(self.disposeBag)
        
        selectedScheduleItem.subscribeOn(MainScheduler.instance).subscribe(onNext: { [weak self] viewModel in
            self?.scheduleController.detailViewController.viewModel = viewModel
            self?.updateSelectedViewModelRegardlessOfTab()
        }).addDisposableTo(self.disposeBag)
    }
    
    private func updateSelectedViewModelRegardlessOfTab() {
        switch activeTab {
        case .schedule:
            self.selectedViewModelRegardlessOfTab = selectedScheduleItemValue
        case .videos:
            self.selectedViewModelRegardlessOfTab = selectedSessionValue
        }
        
        self.updateShelfBasedOnSelectionChange()
        self.updateCurrentActivity(with: selectedViewModelRegardlessOfTab)
    }
    
    private func setupDelegation() {
        let videoDetail = videosController.detailViewController
        
        videoDetail.shelfController.delegate = self
        videoDetail.summaryController.actionsViewController.delegate = self
        
        let scheduleDetail = scheduleController.detailViewController
        
        scheduleDetail.shelfController.delegate = self
        scheduleDetail.summaryController.actionsViewController.delegate = self
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
        if !storage.isEmpty {
            tabController.hideLoading()
        }
        
        storage.tracksObservable.subscribe(onNext: { [weak self] tracks in
            self?.videosController.listViewController.tracks = tracks
        }).dispose()
        
        storage.scheduleObservable.subscribe(onNext: { [weak self] sections in
            self?.scheduleController.listViewController.scheduleSections = sections
        }).dispose()
        
        liveObserver.start()
        
        restoreListStatesIfNeeded()
        
        setupSearch()
    }
    
    private lazy var searchCoordinator: SearchCoordinator = {
        return SearchCoordinator(self.storage,
                                 sessionsController: self.scheduleController.listViewController,
                                 videosController: self.videosController.listViewController)
    }()
    
    private func setupSearch() {
        searchCoordinator.configureFilters()
    }
    
    @IBAction func refresh(_ sender: Any?) {
        syncEngine.syncSessionsAndSchedule()
        syncEngine.syncLiveVideos()
        liveObserver.refresh()
        
        resetAutorefreshTimer()
    }
    
    func startup() {
        RemoteEnvironment.shared.start()
        
        ContributorsFetcher.shared.load()
        
        windowController.contentViewController = tabController
        windowController.showWindow(self)
        
        if storage.isEmpty {
            tabController.showLoading()
        }
        
        NotificationCenter.default.addObserver(forName: .SyncEngineDidSyncSessionsAndSchedule, object: nil, queue: OperationQueue.main) { _ in
            self.updateListsAfterSync(migrate: true)
        }
        
        NotificationCenter.default.addObserver(forName: .WWDCEnvironmentDidChange, object: nil, queue: OperationQueue.main) { _ in
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
    
    func receiveNotification(with userInfo: [String : Any]) -> Bool {
        if liveObserver.processSubscriptionNotification(with: userInfo) {
            return true
        } else if RemoteEnvironment.shared.processSubscriptionNotification(with: userInfo) {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - State restoration
    
    private var didRestoreLists = false
    
    private var deferredLink: DeepLink?
    
    private func saveApplicationState() {
        Preferences.shared.activeTab = activeTab
        Preferences.shared.selectedScheduleItemIdentifier = selectedScheduleItemValue?.identifier
        Preferences.shared.selectedVideoItemIdentifier = selectedSessionValue?.identifier
    }
    
    private func restoreApplicationState() {
        self.tabController.activeTab = Preferences.shared.activeTab
    }
    
    private func restoreListStatesIfNeeded() {
        defer { didRestoreLists = true }
        
        if let link = deferredLink {
            return handle(link: link)
        }
        
        guard !didRestoreLists else { return }
        
        if !scrollToToday() {
            if let identifier = Preferences.shared.selectedScheduleItemIdentifier {
                self.scheduleController.listViewController.selectSession(with: identifier)
            }
        }
        
        if let identifier = Preferences.shared.selectedVideoItemIdentifier {
            self.videosController.listViewController.selectSession(with: identifier)
        }
    }
    
    private func scrollToToday() -> Bool {
        guard liveObserver.isWWDCWeek else { return false }
        
        scheduleController.listViewController.scrollToToday()
        
        return true
    }
    
    // MARK: - Deep linking
    
    func handle(link: DeepLink) {
        guard didRestoreLists else {
            self.deferredLink = link
            return
        }
        
        if link.isForCurrentYear {
            self.tabController.activeTab = .schedule
            self.scheduleController.listViewController.selectSession(with: link.sessionIdentifier)
        } else {
            self.tabController.activeTab = .videos
            self.videosController.listViewController.selectSession(with: link.sessionIdentifier)
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
    
    // MARK: - Autorefresh
    
    private var autorefreshTimer: Timer!
    
    private func resetAutorefreshTimer() {
        if autorefreshTimer != nil {
            autorefreshTimer.invalidate()
            autorefreshTimer = nil
        }
        
        guard Preferences.shared.refreshPeriodically else { return }
        
        autorefreshTimer = Timer.scheduledTimer(timeInterval: Constants.autorefreshInterval, target: self, selector: #selector(refresh(_:)), userInfo: nil, repeats: false)
        autorefreshTimer.tolerance = Constants.autorefreshInterval / 3
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
        
        let legacyURL = URL(fileURLWithPath: PathUtil.appSupportPath + "/default.realm")
        self.migrator = TBUserDataMigrator(legacyDatabaseFileURL: legacyURL, newRealm: storage.realm)
        
        guard self.migrator.needsMigration && !TBUserDataMigrator.presentedMigrationPrompt else {
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
        
        guard let choice = Choice(rawValue: alert.runModal()) else { return }
        
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
