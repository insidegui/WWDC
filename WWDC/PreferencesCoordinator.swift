//
//  PreferencesCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import CommunitySupport
import RxCocoa
import RxSwift

enum PreferencesTab: Int {
    case general
    case account
}

final class PreferencesCoordinator {
    
    private let disposeBag = DisposeBag()
    
    private let windowController: PreferencesWindowController
    
    private let tabController: WWDCTabViewController<PreferencesTab>
    
    private let generalController: GeneralPreferencesViewController
    private let accountController: AccountPreferencesViewController
    
    init() {
        self.windowController = PreferencesWindowController()
        self.tabController = WWDCTabViewController()
        
        // General
        self.generalController = GeneralPreferencesViewController.loadFromStoryboard()
        generalController.identifier = "General"
        let generalItem = NSTabViewItem(viewController: generalController)
        generalItem.label = "General"
        self.tabController.addTabViewItem(generalItem)
        
        // Account
        self.accountController = AccountPreferencesViewController()
        accountController.identifier = "Account"
        let accountItem = NSTabViewItem(viewController: accountController)
        accountItem.label = "Account"
        self.tabController.addTabViewItem(accountItem)
        
        self.windowController.contentViewController = tabController
        
        setupAccountBindings()
    }
    
    func show(in tab: PreferencesTab = .general) {
        windowController.window?.center()
        windowController.showWindow(nil)
        
        tabController.activeTab = tab
    }
    
    func setupAccountBindings() {
        #if ICLOUD
            CMSCommunityCenter.shared.accountStatus.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] status in
                self?.accountController.cloudAccountIsAvailable = (status == .available)
            }).addDisposableTo(self.disposeBag)
            
            CMSCommunityCenter.shared.userProfile.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] profile in
                self?.accountController.profile = profile
            }).addDisposableTo(self.disposeBag)
        #endif
    }
    
}
