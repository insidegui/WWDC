//
//  AppCoordinator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore

final class AppCoordinator {
    
    var windowController: MainWindowController
    
    init(windowController: MainWindowController) {
        self.windowController = windowController
        
        NotificationCenter.default.addObserver(forName: .NSApplicationDidFinishLaunching, object: nil, queue: nil) { _ in self.startup() }
    }
    
    func startup() {
        windowController.showWindow(self)
    }
    
}
