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
    case account
}

final class PreferencesCoordinator {
    
    private let disposeBag = DisposeBag()
    
    private let windowController: PreferencesWindowController
    
    private let tabController: WWDCTabViewController<PreferencesTab>
    private let accountController: AccountPreferencesViewController
    
    init() {
        self.windowController = PreferencesWindowController()
        self.tabController = WWDCTabViewController()
        
        // Account
        self.accountController = AccountPreferencesViewController()
        accountController.identifier = "Account"
        let accountItem = NSTabViewItem(viewController: accountController)
        accountItem.label = "Account"
        self.tabController.addTabViewItem(accountItem)
        
        self.windowController.contentViewController = tabController
        
        setupAccountBindings()
    }
    
    func show() {
        windowController.window?.center()
        windowController.showWindow(nil)
    }
    
    func setupAccountBindings() {
        CMSCommunityCenter.shared.accountStatus.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] status in
            self?.accountController.cloudAccountIsAvailable = (status == .available)
        }).addDisposableTo(self.disposeBag)
        
        CMSCommunityCenter.shared.userProfile.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] profile in
            self?.accountController.profile = profile
        }).addDisposableTo(self.disposeBag)
    }
    
}
