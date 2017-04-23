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
import WWDCPlayer

final class AppCoordinator {
    
    private let disposeBag = DisposeBag()
    
    var storage: Storage
    var syncEngine: SyncEngine
    
    var windowController: MainWindowController
    var tabController: MainTabController
    var videosController: VideosSplitViewController
    
    var currentPlayerController: VideoPlayerViewController?
    
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
        setupDelegation()
        
        NotificationCenter.default.addObserver(forName: .NSApplicationDidFinishLaunching, object: nil, queue: nil) { _ in self.startup() }
    }
    
    var selectedSession: Observable<SessionViewModel?> {
        return videosController.listViewController.selectedSession.asObservable()
    }
    
    private func setupBindings() {
        storage.sessions.bind(to: videosController.listViewController.sessions).addDisposableTo(self.disposeBag)
        selectedSession.bind(to: videosController.detailViewController.viewModel).addDisposableTo(self.disposeBag)
    }
    
    private func setupDelegation() {
        videosController.detailViewController.shelfController.delegate = self
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
    }
    
}

// MARK: - Video playback management

extension AppCoordinator: ShelfViewControllerDelegate {
    
    func shelfViewControllerDidSelectPlay(_ controller: ShelfViewController) {
        guard let viewModel = videosController.detailViewController.viewModel.value else { return }
        
        do {
            let playbackViewModel = try PlaybackViewModel(sessionViewModel: viewModel, storage: storage)
            
            currentPlayerController = VideoPlayerViewController(player: playbackViewModel.player, metadata: playbackViewModel.metadata)
            
            attachPlayerToShelf()
        } catch {
            WWDCAlert.show(with: error)
        }
    }
    
    private func attachPlayerToShelf() {
        guard let playerController = currentPlayerController else { return }
        
        let shelf = videosController.detailViewController.shelfController
        
        shelf.addChildViewController(playerController)
        
        playerController.view.frame = shelf.view.bounds
        playerController.view.alphaValue = 0
        
        shelf.view.addSubview(playerController.view)
        
        shelf.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerController.view]))
        shelf.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": playerController.view]))
        
        playerController.view.alphaValue = 1
    }
    
}
