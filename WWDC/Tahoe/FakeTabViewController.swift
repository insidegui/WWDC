//
//  FakeTabViewController.swift
//  WWDC
//
//  Created by luca on 30.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import Combine

class FakeTabViewController: NSSplitViewController, WWDCTabController {
    typealias Tab = MainWindowTab
    @Published var activeTab: Tab = .explore {
        didSet {
            guard activeTab != oldValue else {
                return
            }
            Task {
                await changeContent()
            }
        }
    }

    var activeTabPublisher: AnyPublisher<Tab, Never> {
        $activeTab.eraseToAnyPublisher()
    }

    private var items = [[NSSplitViewItem]]()

    var activatedItems: [NSSplitViewItem] {
        guard
            items.indices.contains(activeTab.rawValue)
        else {
            return []
        }
        return items[activeTab.rawValue]
    }

    @MainActor private func changeContent() async {
        let newItems = activatedItems

        Task { // along with sidebar
            async let replaceSidebar: () = _replaceSidebarIfNeeded(newItems: newItems)
            async let replaceDetail: () = _replaceDetailIfNeeded(newItems: newItems)
            _ = await [replaceSidebar, replaceDetail]
        }
        let shouldCollapse = newItems.count <= 1
        sidebarItem.canCollapse = true
        await NSAnimationContext.runAnimationGroup { _ in
            sidebarItem.animator().isCollapsed = shouldCollapse
            if !shouldCollapse, let previousPosition = previousSidebarWidth {
                splitView.animator().setPosition(previousPosition, ofDividerAt: 0)
            }
        }
        sidebarItem.canCollapse = false

        topSegmentControl?.selectedSegment = activeTab.rawValue
        if #available(macOS 15.0, *) {
            topSearchItem?.isHidden = activeTab == .explore
            topDownloadItem?.isHidden = activeTab == .explore
        }
    }

    @MainActor
    func _replaceSidebarIfNeeded(newItems: [NSSplitViewItem]) async {
        if newItems.count == 2 {
            await sidebarContainer.replaceContent(newItems[0].viewController)
        }
    }

    @MainActor
    func _replaceDetailIfNeeded(newItems: [NSSplitViewItem]) async {
        if let last = newItems.last { // suppose there were at most 2 items
            await detailContainer.replaceContent(last.viewController)
        }
    }

    private var sidebarItem: NSSplitViewItem!
    private var sidebarContainer: SplitContainer! {
        sidebarItem.viewController as? SplitContainer
    }

    private var detailItem: NSSplitViewItem!
    private var detailContainer: SplitContainer! {
        detailItem.viewController as? SplitContainer
    }

    private var previousSidebarWidth: CGFloat?
    private weak var windowController: WWDCWindowControllerObject?
    init(windowController: WWDCWindowControllerObject) {
        self.windowController = windowController
        super.init(nibName: nil, bundle: nil)
        sidebarItem = NSSplitViewItem(sidebarWithViewController: SplitContainer(nibName: nil, bundle: nil))
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)
        detailItem = NSSplitViewItem(viewController: SplitContainer(nibName: nil, bundle: nil))
        if #available(macOS 26.0, *) {
            detailItem.automaticallyAdjustsSafeAreaInsets = true
        }
        addSplitViewItem(detailItem)
        sidebarContainer.view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        detailContainer.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        detailContainer.view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addTabViewItem(_ tabViewItem: NSTabViewItem) {
        guard let content = tabViewItem.viewController else {
            return
        }
        if let split = content as? NSSplitViewController {
            items.append(split.splitViewItems)
            split.splitViewItems.forEach(split.removeSplitViewItem(_:))
        } else {
            items.append([NSSplitViewItem(viewController: content)])
        }
    }

    private var loadingView: ModalLoadingView?

    func showLoading() {
        loadingView = ModalLoadingView.show(attachedTo: view)
    }

    func hideLoading() {
        loadingView?.hide()
        loadingView = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for item in [topTabItem, topSearchItem, topDownloadItem] {
            if #available(macOS 15.0, *) {
                item?.isHidden = true
            }
        }
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        Task {
            await changeContent()
            for item in [topTabItem/*, topSearchItem, topDownloadItem*/] {
                if #available(macOS 15.0, *) {
                    item?.isHidden = false
                }
            }
        }
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        guard activatedItems.count > 1, sidebarItem.isCollapsed == false else { return }
        previousSidebarWidth = splitView.arrangedSubviews[0].bounds.width
    }
}

private class SplitContainer: NSViewController {
    @MainActor
    func replaceContent(_ content: NSViewController) async {
        await NSAnimationContext.runAnimationGroup { _ in
            view.animator().alphaValue = 0
        }
        children.forEach { $0.removeFromParent() }
        view.subviews.forEach { $0.removeFromSuperview() }
        addChild(content)
        view.addSubview(content.view)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        await NSAnimationContext.runAnimationGroup { _ in
            view.animator().alphaValue = 1
        }
    }
}
