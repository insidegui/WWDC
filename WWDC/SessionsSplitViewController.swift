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
    
    init(listStyle: SessionsListStyle) {
        listViewController = SessionsTableViewController(style: listStyle)
        detailViewController = SessionDetailsViewController(listStyle: listStyle)
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.wantsLayer = true
        
        let listItem = NSSplitViewItem(sidebarWithViewController: listViewController)
        let detailItem = NSSplitViewItem(viewController: detailViewController)
        
        addSplitViewItem(listItem)
        addSplitViewItem(detailItem)
        
        listViewController.view.setContentHuggingPriority(NSLayoutPriorityDefaultHigh, for: .horizontal)
        detailViewController.view.setContentHuggingPriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        detailViewController.view.setContentCompressionResistancePriority(NSLayoutPriorityDefaultHigh, for: .horizontal)
    }
    
    override func toggleSidebar(_ sender: Any?) {
        super.toggleSidebar(sender)
        
        // for some reason the item was getting disabled after the user clicked on it ¯\_(ツ)_/¯
        if let item = sender as? NSMenuItem {
            item.isEnabled = true
            item.target = self
            item.action = #selector(toggleSidebar)
        }
    }
    
}

