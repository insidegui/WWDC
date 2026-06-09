//
//  SessionsSplitViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine

enum SessionsListStyle {
    case schedule
    case videos
}

final class SessionsSplitViewController: NSSplitViewController {

    let listViewController: SessionsTableViewController
    let detailViewController: SessionDetailsViewController
    var isResizingSplitView = false
    let windowController: MainWindowController
    var setupDone = false
    private var cancellables: Set<AnyCancellable> = []

    /// The split view item hosting the session list sidebar. Retained so its
    /// collapsed state can be toggled, observed and synced across tabs.
    private var sidebarItem: NSSplitViewItem!

    /// Guards against feedback loops while mirroring collapse state from another tab.
    private var isSyncingCollapse = false

    init(windowController: MainWindowController, listViewController: SessionsTableViewController) {
        self.windowController = windowController
        self.listViewController = listViewController
        let detailViewController = SessionDetailsViewController()
        self.detailViewController = detailViewController

        super.init(nibName: nil, bundle: nil)

        NotificationCenter
            .default
            .publisher(for: .sideBarSizeSyncNotification)
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] notification in
                self?.syncSplitView(notification: notification)
            }
            .store(in: &cancellables)

        NotificationCenter
            .default
            .publisher(for: .sideBarCollapseSyncNotification)
            .sink { [weak self] notification in
                self?.applyCollapseSync(notification: notification)
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true

        let listItem = NSSplitViewItem(sidebarWithViewController: listViewController)
        listItem.canCollapse = true
        sidebarItem = listItem
        let detailItem = NSSplitViewItem(viewController: detailViewController)

        addSplitViewItem(listItem)
        addSplitViewItem(detailItem)

        listViewController.view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        detailViewController.view.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Mirror collapse state to the other tab's split view so both stay consistent
        // during a session. Catches both the toggleSidebar: action and drag-to-collapse.
        listItem
            .publisher(for: \.isCollapsed)
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] collapsed in
                guard let self, !self.isSyncingCollapse else { return }
                // Record the shared session state so the other (possibly not-yet-loaded) tab adopts it.
                self.windowController.sidebarState.collapsed = collapsed
                NotificationCenter.default.post(
                    name: .sideBarCollapseSyncNotification,
                    object: self.splitView,
                    userInfo: ["collapsed": collapsed]
                )
            }
            .store(in: &cancellables)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        if !setupDone {
            if let initWidth = windowController.sidebarState.initialWidth {
                splitView.setPosition(initWidth, ofDividerAt: 0)
            }
            // Adopt the shared collapsed state in case it changed in another tab before
            // this one was lazily loaded.
            if sidebarItem.isCollapsed != windowController.sidebarState.collapsed {
                isSyncingCollapse = true
                sidebarItem.isCollapsed = windowController.sidebarState.collapsed
                isSyncingCollapse = false
            }
            setupDone = true
        }
    }

    @objc private func syncSplitView(notification: Notification) {
        guard let notificationSourceSplitView = notification.object as? NSSplitView else {
            return
        }
        // Xcode 16 + macOS 15: 0
        // Xcode 16 + macOS 26: 0
        // Xcode 26 + macOS 15: 0
        // Xcode 26 + macOS 26: 3
#if compiler(>=6.2) // Xcode 26+
        let targetSubviewIndex = if #available(macOS 26.0, *) { 3 } else { 0 }
#else
        let targetSubviewIndex = if #available(macOS 26.0, *) { 2 } else { 0 }
#endif

        guard notificationSourceSplitView !== splitView else {
            // If own split view is altered, change split view initialisation width for other tabs.
            // Skip while collapsed so the ~0pt collapsed width is never persisted as the sidebar width.
            if !sidebarItem.isCollapsed {
                windowController.sidebarState.initialWidth = notificationSourceSplitView.subviews[targetSubviewIndex].bounds.width
            }
            return
        }
        // If THIS tab's sidebar is already collapsed, skip applying the incoming width.
        // Width-sync is throttled 250 ms so a trailing notification can arrive after
        // the collapse-sync; calling setPosition here would re-expand the sidebar.
        guard !sidebarItem.isCollapsed else { return }
        guard splitView.subviews.count > 0, notificationSourceSplitView.subviews.count > 0 else {
            return
        }
        guard splitView.subviews[targetSubviewIndex].bounds.width != notificationSourceSplitView.subviews[targetSubviewIndex].bounds.width else {
            return
        }

        // Prevent a split view sync notification from being sent to the other controllers
        // in response to this programmatic resize
        isResizingSplitView = true
        splitView.setPosition(notificationSourceSplitView.subviews[targetSubviewIndex].bounds.width, ofDividerAt: 0)
        isResizingSplitView = false
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        guard isResizingSplitView == false else { return }
        guard setupDone else { return }
        // Don't broadcast a width sync for a collapse/expand; collapse state has its own sync.
        guard !sidebarItem.isCollapsed else { return }

        // This notification should only be posted in response to user input
        NotificationCenter.default.post(name: .sideBarSizeSyncNotification, object: splitView, userInfo: nil)
    }

    /// Mirrors a collapse/expand performed in another tab's split view onto this one.
    private func applyCollapseSync(notification: Notification) {
        // The split view item only exists once this tab's view has loaded. A not-yet-loaded
        // tab will adopt the shared state via windowController.sidebarState.collapsed in viewWillAppear.
        guard let sidebarItem else { return }
        guard let sourceSplitView = notification.object as? NSSplitView, sourceSplitView !== splitView else { return }
        guard let collapsed = notification.userInfo?["collapsed"] as? Bool else { return }
        guard sidebarItem.isCollapsed != collapsed else { return }

        // The inactive tab isn't visible, so apply directly without animation.
        isSyncingCollapse = true
        sidebarItem.isCollapsed = collapsed
        isSyncingCollapse = false
    }
}

extension Notification.Name {
    public static let sideBarSizeSyncNotification = NSNotification.Name("WWDCSplitViewSizeSyncNotification")
    public static let sideBarCollapseSyncNotification = NSNotification.Name("WWDCSidebarCollapseSyncNotification")
}
