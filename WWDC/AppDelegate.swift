//
//  AppDelegate.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {

    let coordinator = AppCoordinator(windowController: MainWindowController())

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_:replyEvent:)), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])

        LoggingHelper.install()

        NSApp.registerForRemoteNotifications(matching: [])
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        coordinator.receiveNotification(with: userInfo)
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor?, replyEvent: NSAppleEventDescriptor?) {
        guard let event = event else { return }
        guard let urlString = event.paramDescriptor(forKeyword: UInt32(keyDirectObject))?.stringValue else { return }
        guard let url = URL(string: urlString) else { return }
        guard let link = DeepLink(url: url) else { return }

        coordinator.handle(link: link, deferIfNeeded: true)
    }

    @IBAction func showPreferences(_ sender: Any) {
        coordinator.showPreferences(sender)
    }

    @IBAction func reload(_ sender: Any) {
        coordinator.refresh(sender)
    }

    @IBAction func showAboutWindow(_ sender: Any) {
        coordinator.showAboutWindow()
    }

    @IBAction func viewFeatured(_ sender: Any) {
        coordinator.showFeatured()
    }

    @IBAction func viewSchedule(_ sender: Any) {
        coordinator.showSchedule()
    }

    @IBAction func viewVideos(_ sender: Any) {
        coordinator.showVideos()
    }

    func applicationWillBecomeActive(_ notification: Notification) {

        if coordinator.windowController.window?.isVisible == false {
            coordinator.windowController.showWindow(self)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {

        if !flag {
            coordinator.windowController.showWindow(sender)

            return true
        }

        return false
    }
}

extension AppDelegate: SUUpdaterDelegate {

    func updaterMayCheck(forUpdates updater: SUUpdater) -> Bool {
        #if DEBUG
            return ProcessInfo.processInfo.arguments.contains("--enable-updates")
        #else
            return true
        #endif
    }
}
