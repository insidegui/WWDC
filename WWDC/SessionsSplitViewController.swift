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
    var isResizingSplitView: Bool = false
    
    init(listStyle: SessionsListStyle) {
        listViewController = SessionsTableViewController(style: listStyle)
        detailViewController = SessionDetailsViewController(listStyle: listStyle)
        
        super.init(nibName: nil, bundle: nil)!
        NotificationCenter.default.addObserver(self, selector: #selector(syncSplitView(notification:)), name: Notification.Name.NSSplitViewDidResizeSubviews, object: nil)
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
        
        listViewController.view.setContentHuggingPriority(NSLayoutPriorityDefaultHigh, for: .horizontal)
        detailViewController.view.setContentHuggingPriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        detailViewController.view.setContentCompressionResistancePriority(NSLayoutPriorityDefaultHigh, for: .horizontal)
    }
    
    @objc private func syncSplitView(notification: Notification) {
        guard isResizingSplitView == false else {
            return
        }
        guard notification.userInfo?["NSSplitViewDividerIndex"] != nil else {
            return
        }
        guard let otherSplitView = notification.object as? NSSplitView else {
            return
        }
        guard otherSplitView != self.splitView else {
            return
        }
        guard  splitView.subviews.count > 0, otherSplitView.subviews.count > 0 else {
            return
        }
        guard splitView.subviews[0].bounds.width != otherSplitView.subviews[0].bounds.width else {
            return
        }
        
        isResizingSplitView = true
        splitView.setPosition(otherSplitView.subviews[0].bounds.width, ofDividerAt: 0)
        isResizingSplitView = false
    }
}

