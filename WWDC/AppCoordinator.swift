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
    
    var storage: Storage
    var syncEngine: SyncEngine
    var downloadManager: DownloadManager
    
    var windowController: MainWindowController
    var tabController: MainTabController
    
    var scheduleController: SessionsSplitViewController
    var videosController: SessionsSplitViewController
    
    var currentPlayerController: VideoPlayerViewController?
    
    var currentActivity: NSUserActivity?
    
    init(windowController: MainWindowController) {
        let filePath = PathUtil.appSupportPath + "/ConfCore.realm"
        
        var realmConfig = Realm.Configuration(fileURL: URL(fileURLWithPath: filePath))
        realmConfig.schemaVersion = Constants.coreSchemaVersion
        
        let client = AppleAPIClient(environment: .current)
        
        do {
            self.storage = try Storage(realmConfig)
            
            self.syncEngine = SyncEngine(storage: storage, client: client)
            
            self.downloadManager = DownloadManager(storage)
        } catch {
            fatalError("Realm initialization error: \(error)")
        }
        
        self.tabController = MainTabController()
        
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
        
        setupBindings()
        setupDelegation()
        
        NotificationCenter.default.addObserver(forName: .NSApplicationDidFinishLaunching, object: nil, queue: nil) { _ in self.startup() }
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
    
    /// The viewModel for the current playback session
    var currentPlaybackViewModel: PlaybackViewModel?
    
    private func setupBindings() {
        selectedSession.subscribeOn(MainScheduler.instance).subscribe(onNext: { [weak self] viewModel in
            self?.videosController.detailViewController.viewModel = viewModel
        }).addDisposableTo(self.disposeBag)
        
        selectedScheduleItem.subscribeOn(MainScheduler.instance).subscribe(onNext: { [weak self] viewModel in
            self?.scheduleController.detailViewController.viewModel = viewModel
        }).addDisposableTo(self.disposeBag)
        
        selectedSession.subscribe(onNext: updateCurrentActivity).addDisposableTo(self.disposeBag)
        selectedScheduleItem.subscribe(onNext: updateCurrentActivity).addDisposableTo(self.disposeBag)
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
            }
        } else {
            doUpdateLists()
        }
    }
    
    private func doUpdateLists() {
        storage.tracksObservable.subscribe(onNext: { [weak self] tracks in
            self?.videosController.listViewController.tracks = tracks
        }).dispose()
        
        storage.scheduleObservable.subscribe(onNext: { [weak self] sections in
            self?.scheduleController.listViewController.scheduleSections = sections
        }).dispose()
    }
    
    @IBAction func refresh(_ sender: Any?) {
        syncEngine.syncSessionsAndSchedule()
        syncEngine.syncLiveVideos()
    }
    
    func startup() {
        windowController.contentViewController = tabController
        windowController.showWindow(self)
        
        NotificationCenter.default.addObserver(forName: .SyncEngineDidSyncSessionsAndSchedule, object: nil, queue: OperationQueue.main) { _ in
            self.updateListsAfterSync(migrate: true)
        }
        
        refresh(nil)
        updateListsAfterSync()
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
        
        guard self.migrator.needsMigration && !self.migrator.presentedMigrationPrompt else {
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
        
        self.migrator.presentedMigrationPrompt = true
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
