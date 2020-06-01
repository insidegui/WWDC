//
//  PreferencesCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxCocoa
import RxSwift
import ConfCore

enum PreferencesTab: Int {
    case general
    case playback
}

final class PreferencesCoordinator {

    private let disposeBag = DisposeBag()

    private let windowController: PreferencesWindowController

    private let tabController: WWDCTabViewController<PreferencesTab>

    private let generalController: GeneralPreferencesViewController
    private let playbackController: PlaybackPreferencesViewController

    #if ICLOUD
    var userDataSyncEngine: UserDataSyncEngine? {
        get {
            return generalController.userDataSyncEngine
        }
        set {
            generalController.userDataSyncEngine = newValue
        }
    }
    #endif

    init(syncEngine: SyncEngine) {
        windowController = PreferencesWindowController()
        tabController = WWDCTabViewController(windowController: windowController)

        // General
        generalController = GeneralPreferencesViewController.loadFromStoryboard(syncEngine: syncEngine)
        generalController.identifier = NSUserInterfaceItemIdentifier(rawValue: "General")
        let generalItem = NSTabViewItem(viewController: generalController)
        generalItem.label = "General"
        tabController.addTabViewItem(generalItem)

        // Playback
        playbackController = PlaybackPreferencesViewController.loadFromStoryboard()
        playbackController.identifier = NSUserInterfaceItemIdentifier(rawValue: "videos")
        let playbackItem = NSTabViewItem(viewController: playbackController)
        playbackItem.label = "Playback"
        tabController.addTabViewItem(playbackItem)

        windowController.contentViewController = tabController
    }

    private func commonInit() {

    }

    func show(in tab: PreferencesTab = .general) {
        windowController.window?.center()
        windowController.showWindow(nil)

        tabController.activeTab = tab
    }

}
