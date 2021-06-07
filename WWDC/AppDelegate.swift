//
//  AppDelegate.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Sparkle
import Siesta
@_exported import ConfUIFoundation
import ConfCore
import RealmSwift
import SwiftUI
import os.log

extension Notification.Name {
    static let openWWDCURL = Notification.Name(rawValue: "OpenWWDCURLNotification")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private lazy var agentController = WWDCAgentController()
    
    private let log = OSLog(subsystem: "io.wwdc.app", category: String(describing: AppDelegate.self))

    private lazy var commandsReceiver = AppCommandsReceiver()
    
    private(set) var coordinator: AppCoordinator? {
        didSet {
            if coordinator != nil {
                openPendingDeepLinkIfNeeded()
            }
        }
    }
    
    var startedAsAgent = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_:replyEvent:)), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))

        if ProcessInfo.processInfo.arguments.contains("--background") {
            NSApp.setActivationPolicy(.accessory)
            startedAsAgent = true
            os_log("WWDC running in background mode to respond to deep-linked commands", log: self.log, type: .default)
        } else {
            NSApp.setActivationPolicy(.regular)
        }

        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)

        #if ICLOUD
        ConfCoreCapabilities.isCloudKitEnabled = true
        #endif
    }

    private var urlObservationToken: NSObjectProtocol?

    private let boot = Boot()

    private var migrationSplashScreenWorkItem: DispatchWorkItem?
    private let slowMigrationToleranceInSeconds: TimeInterval = 1.5

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": false])
        
        agentController.registerAgentVersion()

        NSApp.registerForRemoteNotifications(matching: [])

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "WWDCEnableNetworkDebugging") {
            SiestaLog.Category.enabled = .all
        }
        #endif

        urlObservationToken = NotificationCenter.default.addObserver(forName: .openWWDCURL, object: nil, queue: .main) { [weak self] note in
            guard let url = note.object as? URL else { return }
            self?.openURL(url)
        }

        let item = DispatchWorkItem(block: showMigrationSplashScreen)
        migrationSplashScreenWorkItem = item

        DispatchQueue.main.asyncAfter(deadline: .now() + slowMigrationToleranceInSeconds, execute: item)

        boot.bootstrapDependencies { [unowned self] result in
            self.migrationSplashScreenWorkItem?.cancel()
            self.migrationSplashScreenWorkItem = nil
            self.hideMigrationSplash()

            switch result {
            case .failure(let error):
                self.handleBootstrapError(error)
            case .success(let dependencies):
                self.startupUI(using: dependencies.storage, syncEngine: dependencies.syncEngine)
            }
        }

        ImageDownloadCenter.shared.deleteLegacyImageCacheIfNeeded()
    }
    
    private var storage: Storage?
    private var syncEngine: SyncEngine?

    private func startupUI(using storage: Storage, syncEngine: SyncEngine, force: Bool = false) {
        self.storage = storage
        self.syncEngine = syncEngine
        
        if !force {
            guard !startedAsAgent else {
                os_log("Skipping UI since we're running as an agent", log: self.log, type: .debug)
                return
            }
        }
        
        coordinator = AppCoordinator(
            windowController: MainWindowController(),
            storage: storage,
            syncEngine: syncEngine
        )
        coordinator?.windowController.showWindow(self)
        coordinator?.startup()
    }

    private func handleBootstrapError(_ error: Boot.BootstrapError) {
        if error.code == .unusableStorage {
            handleStorageError(error)
        } else {
            let alert = NSAlert()
            alert.messageText = "Failed to start"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    private func handleStorageError(_ error: Boot.BootstrapError) {
        let alert = NSAlert()
        alert.messageText = "Failed to start"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "Quit")

        alert.runModal()
        NSApp.terminate(self)
    }

    private lazy var slowMigrationController: NSWindowController = {
        let viewController = NSHostingController(rootView: SlowMigrationView())
        let windowController = NSWindowController(window: NSWindow(contentRect: .zero, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false))

        windowController.contentViewController = viewController
        windowController.window?.center()
        windowController.window?.isReleasedWhenClosed = true
        windowController.window?.titlebarAppearsTransparent = true

        return windowController
    }()

    private var migrationSplashShown = false

    private func showMigrationSplashScreen() {
        migrationSplashShown = true
        slowMigrationController.showWindow(self)
    }

    private func hideMigrationSplash() {
        guard migrationSplashShown else { return }
        slowMigrationController.close()
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        coordinator?.receiveNotification(with: userInfo)
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor?, replyEvent: NSAppleEventDescriptor?) {
        guard let event = event else { return }
        guard let urlString = event.paramDescriptor(forKeyword: UInt32(keyDirectObject))?.stringValue else { return }
        guard let url = URL(string: urlString) else { return }

        openURL(url)
    }

    private func openURL(_ url: URL) {
        if let command = WWDCAppCommand(from: url) {
            handle(command)
            return
        }
        
        guard let link = DeepLink(url: url) else {
            NSWorkspace.shared.open(url)
            return
        }

        openDeepLink(link)
    }
    
    private var pendingDeepLink: DeepLink?
    
    private func openDeepLink(_ link: DeepLink) {
        guard let coordinator = coordinator else {
            pendingDeepLink = link
            return
        }
        
        coordinator.handle(link: link)
    }
    
    private func openPendingDeepLinkIfNeeded() {
        guard let deepLink = pendingDeepLink else { return }
        
        coordinator?.handle(link: deepLink)
        
        pendingDeepLink = nil
    }

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return false }
        guard let url = userActivity.webpageURL else { return false }
        guard let link = DeepLink(url: url) else { return false }

        coordinator?.handle(link: link)

        return true
    }

    @IBAction func showPreferences(_ sender: Any) {
        coordinator?.showPreferences(sender)
    }

    @IBAction func reload(_ sender: Any) {
        coordinator?.refresh(sender)
    }

    @IBAction func showAboutWindow(_ sender: Any) {
        coordinator?.showAboutWindow()
    }

    @IBAction func viewFeatured(_ sender: Any) {
        coordinator?.showFeatured()
    }

    @IBAction func viewSchedule(_ sender: Any) {
        coordinator?.showSchedule()
    }

    @IBAction func viewVideos(_ sender: Any) {
        coordinator?.showVideos()
    }

    @IBAction func viewCommunity(_ sender: Any) {
        coordinator?.showCommunity()
    }

    @IBAction func viewHelp(_ sender: Any) {
        if let helpUrl = URL(string: "https://github.com/insidegui/WWDC/issues") {
            NSWorkspace.shared.open(helpUrl)
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {

        // Switches to app via application switcher
        if !NSApp.windows.contains(where: { $0.isVisible }) {
            coordinator?.windowController.showWindow(self)
        }
    }
    
    private func activateUI() {
        if coordinator == nil, startedAsAgent, let storage = storage, let syncEngine = syncEngine {
            os_log("Starting up UI late since we started out as an agent", log: self.log, type: .debug)
            
            startupUI(using: storage, syncEngine: syncEngine, force: true)
        }
    
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        activateUI()
        
        // User clicks dock item, double clicks app in finder, etc
        if !flag {
            coordinator?.windowController.showWindow(sender)

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

extension AppDelegate {
    func handle(_ command: WWDCAppCommand) {
        if command.isForeground {
            activateUI()
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        }
        
        if command.modifiesUserContent {
            let needsAgentPrefEnabled: Bool
            
            #if DEBUG
            needsAgentPrefEnabled = !UserDefaults.standard.bool(forKey: "WWDCForceAllowAgentCommands")
            #else
            needsAgentPrefEnabled = true
            #endif
            
            if needsAgentPrefEnabled {
                guard WWDCAgentController.isAgentEnabled else {
                    os_log("Refusing to run command %{public}@ because it's disabled in preferences", log: self.log, type: .error, String(describing: command))
                    return
                }
            }
        }
        
        guard let storage = storage else { return }
        
        if let link = commandsReceiver.handle(command, storage: storage) {
            openDeepLink(link)
        }
    }
}
