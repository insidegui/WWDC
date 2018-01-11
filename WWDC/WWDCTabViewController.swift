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

        transitionOptions = .allowUserInteraction

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

        toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: 0)
        toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: toolbar.items.count)

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
                guard let view = tabItemViews.first(where: { $0.controllerIdentifier == identifier.rawValue }) else { return }

                if indexForChild(with: identifier.rawValue) == selectedTabViewItemIndex {
                    view.state = .on
                } else {
                    view.state = .off
                }
            }

            activeTabVar.value = Tab(rawValue: selectedTabViewItemIndex)!
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func tabItem(with identifier: String) -> NSTabViewItem? {
        return tabViewItems.first { $0.identifier as? String == identifier }
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
