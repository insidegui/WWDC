//
//  MainTabController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class MainTabController: NSTabViewController {

    init() {
        super.init(nibName: nil, bundle: nil)!
        
        identifier = "tabs"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabStyle = .toolbar
        view.wantsLayer = true
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        guard let toolbar = view.window?.toolbar else { return }
        
        toolbar.insertItem(withItemIdentifier: NSToolbarFlexibleSpaceItemIdentifier, at: 0)
        toolbar.insertItem(withItemIdentifier: NSToolbarFlexibleSpaceItemIdentifier, at: toolbar.items.count)
    }
    
    private func tabItem(with identifier: String) -> NSTabViewItem? {
        return tabViewItems.filter({ $0.identifier as? String == identifier }).first
    }
    
    override func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tabItem = tabItem(with: itemIdentifier) else { return nil }
        
        let itemView = TabItemView(frame: .zero)
        
        itemView.title = tabItem.label
        itemView.image = #imageLiteral(resourceName: "videos")
        itemView.state = NSOnState
        
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        
        item.minSize = itemView.bounds.size
        item.maxSize = itemView.bounds.size
        item.view = itemView
        
        return item
    }
    
}
