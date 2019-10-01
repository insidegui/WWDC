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

    private var activeTabVar = BehaviorRelay<Tab>(value: Tab(rawValue: 0)!)

    var rxActiveTab: Observable<Tab> {
        return activeTabVar.asObservable()
    }

    override var selectedTabViewItemIndex: Int {
        didSet {
            guard selectedTabViewItemIndex != oldValue else { return }
            guard selectedTabViewItemIndex >= 0 && selectedTabViewItemIndex < tabViewItems.count else { return }

            tabViewItems.forEach { item in
                guard let identifier = item.viewController?.identifier else { return }
                guard let view = tabBar.items.first(where: { $0.controllerIdentifier == identifier.rawValue }) else { return }

                if indexForChild(with: identifier.rawValue) == selectedTabViewItemIndex {
                    view.state = .on
                } else {
                    view.state = .off
                }
            }

            activeTabVar.accept(Tab(rawValue: selectedTabViewItemIndex)!)
        }
    }

    private(set) lazy var tabBar = WWDCTabViewControllerTabBar()

    init(windowController: WWDCWindowController) {
        super.init(nibName: nil, bundle: nil)

        windowController.titleBarViewController.tabBar = tabBar

        // Preserve the window's size, essentially passing in saved window frame sizes
        let superFrame = view.frame
        if let windowFrame = windowController.window?.frame {
            view.frame = NSRect(origin: superFrame.origin, size: windowFrame.size)
        }

        tabStyle = .unspecified
        identifier = NSUserInterfaceItemIdentifier(rawValue: "tabs")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func addTabViewItem(_ tabViewItem: NSTabViewItem) {
        super.addTabViewItem(tabViewItem)

        let itemView = TabItemView(frame: .zero)

        itemView.title = tabViewItem.label
        itemView.controllerIdentifier = (tabViewItem.viewController?.identifier).map { $0.rawValue } ?? ""
        itemView.image = NSImage(named: itemView.controllerIdentifier.lowercased())
        itemView.alternateImage = NSImage(named: itemView.controllerIdentifier.lowercased() + "-filled")
        itemView.sizeToFit()

        itemView.target = self
        itemView.action = #selector(changeTab)

        itemView.state = (tabViewItems.firstIndex(of: tabViewItem) == selectedTabViewItemIndex) ? .on : .off

        tabBar.addItem(itemView)
    }

    var isTopConstraintAdded = false

    override func  updateViewConstraints() {
        super.updateViewConstraints()

        // The top constraint keeps the tabView from extending
        // under the title bar
        if !isTopConstraintAdded, let window = view.window {
            isTopConstraintAdded = true
            NSLayoutConstraint(item: tabView,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: window.contentLayoutGuide,
                               attribute: .top,
                               multiplier: 1,
                               constant: 0).isActive = true
        }
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

    @objc
    private func changeTab(_ sender: TabItemView) {
        guard let index = indexForChild(with: sender.controllerIdentifier) else { return }

        selectedTabViewItemIndex = index
    }

    private func indexForChild(with identifier: String) -> Int? {
        return tabViewItems.firstIndex { $0.viewController?.identifier?.rawValue == identifier }
    }

    private var loadingView: ModalLoadingView?

    func showLoading() {
        loadingView = ModalLoadingView.show(attachedTo: view)
    }

    func hideLoading() {
        loadingView?.hide()
    }

}
