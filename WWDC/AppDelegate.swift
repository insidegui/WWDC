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
import OSLog

extension Notification.Name {
    static let openWWDCURL = Notification.Name(rawValue: "OpenWWDCURLNotification")
}

class AppDelegate: NSObject, NSApplicationDelegate, Logging {
    
    static let log = makeLogger(subsystem: "io.wwdc.app")

    private lazy var commandsReceiver = AppCommandsReceiver()
    
    private(set) var coordinator: AppCoordinator? {
        didSet {
            if coordinator != nil {
                openPendingDeepLinkIfNeeded()
            }
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_:replyEvent:)), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))

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
        NSApp.registerForRemoteNotifications(matching: [])

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "WWDCEnableNetworkDebugging") {
            SiestaLog.Category.enabled = .all
        }
        #endif

        urlObservationToken = NotificationCenter.default.addObserver(forName: .openWWDCURL, object: nil, queue: .main) { [weak self] note in
            guard let url = note.object as? URL else { return }
            MainActor.assumeIsolated {
                self?.openURL(url)
            }
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
        // setup liquid glass feature settings
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            guard
                let aboutMenu = NSApp.menu?.items.first?.submenu,
                let firstSeparatorIndex = aboutMenu.items.firstIndex(where: { $0.isSeparatorItem }), // under About
                aboutMenu.items.count > firstSeparatorIndex + 1
            else {
                return
            }

            let liquidGlassItem = NSMenuItem(title: "Try Liquid Glass", action: #selector(tryLiquidGlass(_:)), keyEquivalent: "")
            liquidGlassItem.indentationLevel = 1
            liquidGlassItem.state = TahoeFeatureFlag.isLiquidGlassEnabled ? .on : .mixed
            aboutMenu.insertItem(liquidGlassItem, at: firstSeparatorIndex + 1)
        }
#endif
    }
    
    private var storage: Storage?
    private var syncEngine: SyncEngine?

    @MainActor
    private func startupUI(using storage: Storage, syncEngine: SyncEngine) {
        self.storage = storage
        self.syncEngine = syncEngine

        coordinator = AppCoordinator(
            windowController: MainWindowController(),
            storage: storage,
            syncEngine: syncEngine
        )
    }

    private func handleBootstrapError(_ error: Boot.BootstrapError) {
        switch error.code {
        case .unusableStorage:
            handleStorageError(error)
        case .dataReset:
            break
        default:
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
        /// Prevent migration splash screen from showing up during other types of launch alerts,
        /// such as the data reset confirmation when holding down the Option key.
        guard NSApp.modalWindow == nil else { return }

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

    @MainActor
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor?, replyEvent: NSAppleEventDescriptor?) {
        guard let event = event else { return }
        guard let urlString = event.paramDescriptor(forKeyword: UInt32(keyDirectObject))?.stringValue else { return }
        guard let url = URL(string: urlString) else { return }

        openURL(url)
    }

    @MainActor
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

#if compiler(>=6.2)
    @objc private func tryLiquidGlass(_ sender: NSMenuItem) {
        defer {
            sender.state = TahoeFeatureFlag.isLiquidGlassEnabled ? .on : .mixed
        }
        guard sender.state != .on else {
            TahoeFeatureFlag.isLiquidGlassEnabled.toggle()
            return
        }
        let alert = NSAlert()
        alert.messageText = "This feature is still under development. Are you sure you want to try it out?"
        alert.informativeText = "Please restart the app after changing this setting."
        alert.addButton(withTitle: "YES")
        alert.addButton(withTitle: "NO")
        if alert.runModal() == .alertFirstButtonReturn {
            TahoeFeatureFlag.isLiquidGlassEnabled.toggle()
        }
    }
#endif

    @IBAction func showAboutWindow(_ sender: Any) {
        coordinator?.showAboutWindow()
    }

    @IBAction func viewFeatured(_ sender: Any) {
        coordinator?.showExplore()
    }

    @IBAction func viewSchedule(_ sender: Any) {
        coordinator?.showSchedule()
    }

    @IBAction func viewVideos(_ sender: Any) {
        coordinator?.showVideos()
    }

    @objc func applyFilterState(_ sender: Any?) {
        guard let state = sender as? WWDCFiltersState else { return }

        coordinator?.applyFilter(state: state)
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
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
    @MainActor
    static func run(_ command: WWDCAppCommand) {
        (NSApp.delegate as? Self)?.handle(command, assumeSafe: true)
    }

    @MainActor
    func handle(_ command: WWDCAppCommand, assumeSafe: Bool = false) {
        if command.isForeground {
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        }

        guard let storage = storage else { return }
        
        if let link = commandsReceiver.handle(command, storage: storage) {
            openDeepLink(link)
        }
    }
}
