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

final class AppCoordinator {
    
    private let disposeBag = DisposeBag()
    
    var storage: Storage
    var syncEngine: SyncEngine
    var downloadManager: DownloadManager
    
    var windowController: MainWindowController
    var tabController: MainTabController
    var videosController: VideosSplitViewController
    
    var currentPlayerController: VideoPlayerViewController?
    
    var currentActivity: NSUserActivity?
    
    init(windowController: MainWindowController) {
        let filePath = PathUtil.appSupportPath + "/ConfCore.realm"
        
        var realmConfig = Realm.Configuration(fileURL: URL(fileURLWithPath: filePath))
        realmConfig.schemaVersion = 2
        realmConfig.migrationBlock = { _, _ in }
        
        let client = AppleAPIClient(environment: .current)
        
        do {
            self.storage = try Storage(realmConfig)
            
            self.syncEngine = SyncEngine(storage: storage, client: client)
            
            self.downloadManager = DownloadManager(storage)
        } catch {
            fatalError("Realm initialization error: \(error)")
        }
        
        self.tabController = MainTabController()
        
        // Videos
        self.videosController = VideosSplitViewController()
        let videosItem = NSTabViewItem(viewController: videosController)
        videosItem.label = "Videos"
        self.tabController.addTabViewItem(videosItem)
        
        self.windowController = windowController
        
        setupBindings()
        setupDelegation()
        
        NotificationCenter.default.addObserver(forName: .NSApplicationDidFinishLaunching, object: nil, queue: nil) { _ in self.startup() }
    }
    
    var selectedSession: Observable<SessionViewModel?> {
        return videosController.listViewController.selectedSession.asObservable()
    }
    
    var selectedSessionValue: SessionViewModel? {
        return videosController.listViewController.selectedSession.value
    }
    
    private func setupBindings() {
        selectedSession.bind(to: videosController.detailViewController.viewModel).addDisposableTo(self.disposeBag)
        
        selectedSession.subscribe(onNext: updateCurrentActivity).addDisposableTo(self.disposeBag)
    }
    
    private func setupDelegation() {
        let detail = videosController.detailViewController
        
        detail.shelfController.delegate = self
        detail.summaryController.actionsViewController.delegate = self
    }
    
    private func updateListsAfterSync() {
        self.videosController.listViewController.sessions = storage.sessions
    }
    
    @IBAction func refresh(_ sender: Any?) {
        syncEngine.syncSessionsAndSchedule()
    }
    
    func startup() {
        windowController.contentViewController = tabController
        windowController.showWindow(self)
        
        NotificationCenter.default.addObserver(forName: .SyncEngineDidSyncSessionsAndSchedule, object: nil, queue: OperationQueue.main) { _ in
            self.updateListsAfterSync()
        }
        
        refresh(nil)
    }
    
}
