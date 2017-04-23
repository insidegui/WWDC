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

final class AppCoordinator {
    
    private let disposeBag = DisposeBag()
    
    var storage: Storage
    var syncEngine: SyncEngine
    
    var windowController: MainWindowController
    var tabController: MainTabController
    var videosController: VideosSplitViewController
    
    init(windowController: MainWindowController) {
        let filePath = PathUtil.appSupportPath + "/ConfCore.realm"
        let realmConfig = Realm.Configuration(fileURL: URL(fileURLWithPath: filePath))
        
        let client = AppleAPIClient(environment: .current)
        
        do {
            self.storage = try Storage(realmConfig)
            
            self.syncEngine = SyncEngine(storage: storage, client: client)
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
        
        NotificationCenter.default.addObserver(forName: .NSApplicationDidFinishLaunching, object: nil, queue: nil) { _ in self.startup() }
    }
    
    private func setupBindings() {
        let selectedSession = videosController.listViewController.selectedSession.asObservable()
        
        selectedSession.bind(to: videosController.detailViewController.summaryController.viewModel).addDisposableTo(self.disposeBag)
        selectedSession.bind(to: videosController.detailViewController.playerController.viewModel).addDisposableTo(self.disposeBag)
    }
    
    @IBAction func refresh(_ sender: Any?) {
        syncEngine.syncSessionsAndSchedule { error in
            if let error = error {
                // TODO: better error handling
                print("Error while syncing sessions and schedule: \(error)")
            }
        }
    }
    
    func startup() {
        windowController.contentViewController = tabController
        windowController.showWindow(self)
        
        refresh(nil)
        
        storage.sessions.bind(to: videosController.listViewController.sessions).addDisposableTo(self.disposeBag)
    }
    
}
