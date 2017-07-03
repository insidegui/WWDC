//
//  WWDCTabViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

extension Notification.Name {
    static let WWDCTabViewControllerDidFinishLoading = Notification.Name("WWDCTabViewControllerDidFinishLoading")
}

class WWDCTabViewController<Tab: RawRepresentable>: NSTabViewController where Tab.RawValue == Int {
    
    var activeTab: Tab {
        get {
            return Tab(rawValue: self.selectedTabViewItemIndex)!
        }
        set {
            self.selectedTabViewItemIndex = newValue.rawValue
        }
    }
    
    private var activeTabVar = Variable<Tab>(Tab(rawValue: 0)!)
    
    var rxActiveTab: Observable<Tab> {
        return activeTabVar.asObservable()
    }
    
    init(windowController: NSWindowController) {
        super.init(nibName: nil, bundle: nil)!

        // Preserve the window's size, essentially passing in saved window frame sizes
        let superFrame = view.frame
        if let windowFrame = windowController.window?.frame {
            view.frame = NSRect(origin: superFrame.origin, size: windowFrame.size)
        }

        identifier = "tabs"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        transitionOptions = [.allowUserInteraction]
        
        tabStyle = .toolbar
        view.wantsLayer = true
    }
    
    private var sentStatupNotification = false
    
    private var isConfigured = false
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        configureIfNeeded()
    }
    
    private func configureIfNeeded() {
        guard !isConfigured else { return }
        
        guard let toolbar = view.window?.toolbar else { return }
        
        isConfigured = true
        
        toolbar.insertItem(withItemIdentifier: NSToolbarFlexibleSpaceItemIdentifier, at: 0)
        toolbar.insertItem(withItemIdentifier: NSToolbarFlexibleSpaceItemIdentifier, at: toolbar.items.count)
        
        addObserver(self, forKeyPath: #keyPath(selectedTabViewItemIndex), options: [.initial, .new], context: nil)
        
        if !sentStatupNotification {
            sentStatupNotification = true
            NotificationCenter.default.post(name: .WWDCTabViewControllerDidFinishLoading, object: self)
        }
    }
    
    deinit {
        removeObserver(self, forKeyPath: #keyPath(selectedTabViewItemIndex))
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(selectedTabViewItemIndex) {
            guard selectedTabViewItemIndex >= 0 && selectedTabViewItemIndex < tabViewItems.count else { return }
            
            tabViewItems.forEach { item in
                guard let identifier = item.viewController?.identifier else { return }
                guard let view = self.tabItemViews.first(where: { $0.controllerIdentifier == identifier }) else { return }
                
                if self.indexForChild(with: identifier) == self.selectedTabViewItemIndex {
                    view.state = NSOnState
                } else {
                    view.state = NSOffState
                }
            }
            
            self.activeTabVar.value = Tab(rawValue: self.selectedTabViewItemIndex)!
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func tabItem(with identifier: String) -> NSTabViewItem? {
        return tabViewItems.filter({ $0.identifier as? String == identifier }).first
    }
    
    override func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tabItem = tabItem(with: itemIdentifier) else { return nil }
        
        let itemView = TabItemView(frame: .zero)
        
        itemView.title = tabItem.label
        itemView.controllerIdentifier = tabItem.viewController?.identifier ?? ""
        itemView.image = NSImage(named: itemView.controllerIdentifier.lowercased())
        itemView.alternateImage = NSImage(named: itemView.controllerIdentifier.lowercased() + "-filled")
        
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        
        item.minSize = itemView.bounds.size
        item.maxSize = itemView.bounds.size
        item.view = itemView
        
        item.target = self
        item.action = #selector(changeTab(_:))
        
        itemView.state = (tabViewItems.index(of: tabItem) == self.selectedTabViewItemIndex) ? NSOnState : NSOffState
        
        return item
    }
    
    @objc private func changeTab(_ sender: TabItemView) {
        guard let index = indexForChild(with: sender.controllerIdentifier) else { return }
        
        self.selectedTabViewItemIndex = index
    }
    
    private func indexForChild(with identifier: String) -> Int? {
        return tabViewItems.index(where: { $0.viewController?.identifier == identifier })
    }
    
    private var tabItemViews: [TabItemView] {
        return self.view.window?.toolbar?.items.flatMap({ $0.view as? TabItemView }) ?? []
    }
    
    private var loadingView: ModalLoadingView?
    
    func showLoading() {
        loadingView = ModalLoadingView.show(attachedTo: self.view)
    }
    
    func hideLoading() {
        loadingView?.hide()
    }
    
}
