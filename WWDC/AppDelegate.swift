//
//  AppDelegate.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import CommunitySupport

class AppDelegate: NSObject, NSApplicationDelegate {

    let coordinator = AppCoordinator(windowController: MainWindowController())
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.registerForRemoteNotifications(matching: [])
    }
    
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        CMSCommunityCenter.shared.processNotification(userInfo: userInfo)
    }

}

