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

class WWDCTabViewController<Tab: RawRepresentable>: NSTabViewController where Tab.RawValue == Int {

    var activeTab: Tab {
        get {
            return Tab(rawValue: selectedTabViewItemIndex)!
        }
        set {
            selectedTabViewItemIndex = newValue.rawValue
        }
    }

    private var activeTabVar = Variable<Tab>(Tab(rawValue: 0)!)

    var rxActiveTab: Observable<Tab> {
        return activeTabVar.asObservable()
    }

    override var selectedTabViewItemIndex: Int {
        didSet {
            guard selectedTabViewItemIndex >= 0 && selectedTabViewItemIndex < tabViewItems.count else { return }

            tabViewItems.forEach { item in
                guard let identifier = item.viewController?.identifier else { return }
                guard let view = tabItemViews.first(where: { $0.controllerIdentifier == identifier.rawValue }) else { return }

                if indexForChild(with: identifier.rawValue) == selectedTabViewItemIndex {
                    view.state = .on
                } else {
                    view.state = .off
                }
            }

            activeTabVar.value = Tab(rawValue: selectedTabViewItemIndex)!
        }
    }

    init(windowController: NSWindowController) {
        super.init(nibName: nil, bundle: nil)

        // Preserve the window's size, essentially passing in saved window frame sizes
        let superFrame = view.frame
        if let windowFrame = windowController.window?.frame {
            view.frame = NSRect(origin: superFrame.origin, size: windowFrame.size)
        }

        identifier = NSUserInterfaceItemIdentifier(rawValue: "tabs")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tabStyle = .toolbar
        view.wantsLayer = true
    }

    private func tabItem(with identifier: String) -> NSTabViewItem? {
        return tabViewItems.first { $0.identifier as? String == identifier }
    }

    override func transition(from fromViewController: NSViewController, to toViewController: NSViewController, options: NSViewController.TransitionOptions = [], completionHandler completion: (() -> Void)? = nil) {

        // Disable the crossfade animation here instead of removing it from the transition options
        // This works around a bug in NSSearchField in which the animation of resigning first responder
        // would get stuck if you switched tabs while the search field was first responder. Upon returning
        // to the original tab, you would see the search field's placeholder animate back to center
        // search_field_responder_tag
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0
            super.transition(from: fromViewController, to: toViewController, options: options, completionHandler: completion)
        })
    }

    override func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {

        // Center the tab bar's NSToolbarItem's be putting flexible space at the beginning and end of
        // the array. Super's implementation returns the NSToolbarItems that represent the NSTabViewItems
        var defaultItemIdentifiers = super.toolbarDefaultItemIdentifiers(toolbar)
        defaultItemIdentifiers.insert(.flexibleSpace, at: 0)
        defaultItemIdentifiers.append(.flexibleSpace)

        return defaultItemIdentifiers
    }

    override func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tabItem = tabItem(with: itemIdentifier.rawValue) else { return nil }

        let itemView = TabItemView(frame: .zero)

        itemView.title = tabItem.label
        itemView.controllerIdentifier = (tabItem.viewController?.identifier).map { $0.rawValue } ?? ""
        itemView.image = NSImage(named: NSImage.Name(rawValue: itemView.controllerIdentifier.lowercased()))
        itemView.alternateImage = NSImage(named: NSImage.Name(rawValue: itemView.controllerIdentifier.lowercased() + "-filled"))

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)

        item.minSize = itemView.bounds.size
        item.maxSize = itemView.bounds.size
        item.view = itemView

        item.target = self
        item.action = #selector(changeTab)

        itemView.state = (tabViewItems.index(of: tabItem) == selectedTabViewItemIndex) ? .on : .off

        return item
    }

    @objc private func changeTab(_ sender: TabItemView) {
        guard let index = indexForChild(with: sender.controllerIdentifier) else { return }

        selectedTabViewItemIndex = index
    }

    private func indexForChild(with identifier: String) -> Int? {
        return tabViewItems.index { $0.viewController?.identifier?.rawValue == identifier }
    }

    private var tabItemViews: [TabItemView] {
        return view.window?.toolbar?.items.flatMap { $0.view as? TabItemView } ?? []
    }

    private var loadingView: ModalLoadingView?

    func showLoading() {
        loadingView = ModalLoadingView.show(attachedTo: view)
    }

    func hideLoading() {
        loadingView?.hide()
    }

}
