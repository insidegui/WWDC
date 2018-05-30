//
//  SessionsSplitViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

enum SessionsListStyle {
    case schedule
    case videos
}

final class SessionsSplitViewController: NSSplitViewController {

    var listViewController: SessionsTableViewController
    var detailViewController: SessionDetailsViewController
    var isResizingSplitView = false
    var windowController: MainWindowController
    var setupDone = false

    init(windowController: MainWindowController, listStyle: SessionsListStyle) {
        self.windowController = windowController
        listViewController = SessionsTableViewController(style: listStyle)
        detailViewController = SessionDetailsViewController(listStyle: listStyle)

        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(syncSplitView(notification:)), name: .sideBarSizeSyncNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true

        let listItem = NSSplitViewItem(sidebarWithViewController: listViewController)
        listItem.canCollapse = false
        let detailItem = NSSplitViewItem(viewController: detailViewController)

        addSplitViewItem(listItem)
        addSplitViewItem(detailItem)

        listViewController.view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        detailViewController.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        detailViewController.view.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        if !setupDone {
            if let sidebarInitWidth = windowController.sidebarInitWidth {
                splitView.setPosition(sidebarInitWidth, ofDividerAt: 0)
            }
            setupDone = true
        }
    }

    @objc private func syncSplitView(notification: Notification) {
        guard let notificationSourceSplitView = notification.object as? NSSplitView else {
            return
        }
        guard notificationSourceSplitView !== splitView else {
            // If own split view is altered, change split view initialisation width for other tabs
            windowController.sidebarInitWidth = notificationSourceSplitView.subviews[0].bounds.width
            return
        }
        guard splitView.subviews.count > 0, notificationSourceSplitView.subviews.count > 0 else {
            return
        }
        guard splitView.subviews[0].bounds.width != notificationSourceSplitView.subviews[0].bounds.width else {
            return
        }

        // Prevent a split view sync notification from being sent to the other controllers
        // in response to this programmatic resize
        isResizingSplitView = true
        splitView.setPosition(notificationSourceSplitView.subviews[0].bounds.width, ofDividerAt: 0)
        isResizingSplitView = false
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        guard isResizingSplitView == false else { return }
        guard setupDone else { return }

        // This notification should only be posted in response to user input
        NotificationCenter.default.post(name: .sideBarSizeSyncNotification, object: splitView, userInfo: nil)
    }
}

extension Notification.Name {
    public static let sideBarSizeSyncNotification = NSNotification.Name("WWDCSplitViewSizeSyncNotification")
}
