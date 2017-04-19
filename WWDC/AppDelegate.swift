//
//  AppDelegate.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let coordinator = AppCoordinator(windowController: MainWindowController())

}

