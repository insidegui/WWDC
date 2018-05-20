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
    case account
}

final class PreferencesCoordinator {

    private let disposeBag = DisposeBag()

    private let windowController: PreferencesWindowController

    private let tabController: WWDCTabViewController<PreferencesTab>

    private let generalController: GeneralPreferencesViewController

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

    init() {
        windowController = PreferencesWindowController()
        tabController = WWDCTabViewController(windowController: windowController)

        // General
        generalController = GeneralPreferencesViewController.loadFromStoryboard()
        generalController.identifier = NSUserInterfaceItemIdentifier(rawValue: "General")
        let generalItem = NSTabViewItem(viewController: generalController)
        generalItem.label = "General"
        tabController.addTabViewItem(generalItem)

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
