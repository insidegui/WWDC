//
//  PreferencesCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

enum PreferencesTab: Int {
    case account
}

final class PreferencesCoordinator {
    
    private let windowController: PreferencesWindowController
    
    private let tabController: WWDCTabViewController<PreferencesTab>
    
    init() {
        self.windowController = PreferencesWindowController()
        self.tabController = WWDCTabViewController()
        
    }
    
    func show() {
        windowController.window?.center()
        windowController.showWindow(nil)
    }
    
}
