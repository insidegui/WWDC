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
            // If own split view is altered, change split view initialisation width for other tabs
            windowController.sidebarInitWidth = notificationSourceSplitView.subviews[targetSubviewIndex].bounds.width
            return
        }
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

        // This notification should only be posted in response to user input
        NotificationCenter.default.post(name: .sideBarSizeSyncNotification, object: splitView, userInfo: nil)
    }
}

extension Notification.Name {
    public static let sideBarSizeSyncNotification = NSNotification.Name("WWDCSplitViewSizeSyncNotification")
}
