//
//  ReplaceableSplitViewController.swift
//  WWDC
//
//  Created by luca on 30.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import Combine

protocol ReplaceableSplitViewTopAccessoryProvider {
    @available(macOS 26.0, *)
    func topAccessoryViewController() -> NSSplitViewItemAccessoryViewController?
}

@available(macOS 26.0, *)
class ReplaceableSplitViewController: NSSplitViewController, WWDCTabController {
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

    private var items = [[NSViewController?]]()
    private var sessionSelectObserver: AnyCancellable?
    private var transcriptObserver: AnyCancellable?

    var activatedItems: [NSViewController?] {
        guard
            items.indices.contains(activeTab.rawValue)
        else {
            return []
        }
        return items[activeTab.rawValue]
    }

    @MainActor private func changeContent() async {
        sessionSelectObserver?.cancel()
        let newItems = activatedItems
        let sidebarContainer = sidebarItem.container
        let detailContainer = detailItem.container
        let inspectorContainer = inspectorItem.container
        Task { // along with sidebar
            async let replaceSidebar: () = sidebarContainer.replaceContent(newItems[0])
            async let replaceDetail: () = detailContainer.replaceContent(newItems[1])
            async let replaceInspector: () = inspectorContainer.replaceContent(newItems[2])
            _ = await [replaceSidebar, replaceDetail, replaceInspector]
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

        if
            let list = newItems[0] as? NewSessionsTableViewController
        {
            if let detail = newItems[1] as? SessionDetailsViewController {
                sessionSelectObserver = list.$selectedSession.receive(on: DispatchQueue.main).sink { [weak detail] viewModel in
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.35
                        detail?.viewModel = viewModel
                    }
                }
            }
        }

        sidebarItem.isCollapsed = newItems[0] == nil
        inspectorItem.isCollapsed = newItems[2] == nil
    }

    private var sidebarItem: NSSplitViewItem!
    private var detailItem: NSSplitViewItem!
    fileprivate var inspectorItem: NSSplitViewItem!

    private var previousSidebarWidth: CGFloat?
    private weak var windowController: WWDCWindowControllerObject?

    init(windowController: WWDCWindowControllerObject) {
        self.windowController = windowController
        super.init(nibName: nil, bundle: nil)
        sidebarItem = NSSplitViewItem(sidebarWithViewController: SplitContainer(nibName: nil, bundle: nil))
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)
        detailItem = NSSplitViewItem(viewController: SplitContainer(nibName: nil, bundle: nil))
        detailItem.automaticallyAdjustsSafeAreaInsets = true
        addSplitViewItem(detailItem)
        inspectorItem = NSSplitViewItem(inspectorWithViewController: SplitContainer(nibName: nil, bundle: nil))
        inspectorItem.canCollapse = false
        addSplitViewItem(inspectorItem)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func add(list: NSViewController?, detail: NSViewController, inspector: NSViewController? = nil) {
        items.append([
            list,
            detail,
            inspector
        ].compactMap { $0 })
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
            item?.isEnabled = false
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        Task {
            await changeContent()
            for item in [topTabItem, topSearchItem, topDownloadItem] {
                item?.isEnabled = true
            }
        }
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        guard activatedItems.count > 1, sidebarItem.isCollapsed == false else { return }
        previousSidebarWidth = splitView.arrangedSubviews[0].bounds.width
    }
}

@available(macOS 26.0, *)
extension NSViewController {
    private var replaceableSplit: ReplaceableSplitViewController? {
        (parent as? SplitContainer)?.parent as? ReplaceableSplitViewController
    }

    func hideInspector() {
        guard let item = replaceableSplit?.inspectorItem else {
            return
        }
        NSAnimationContext.runAnimationGroup { _ in
            item.animator().isCollapsed = true
        }
    }

    func showInspector(_ content: NSViewController, width: CGFloat = 150) {
        guard
            let inspectorItem = replaceableSplit?.inspectorItem,
            let splitView = replaceableSplit?.splitView
        else {
            return
        }
        inspectorItem.canCollapse = true
        let container = inspectorItem.container
        Task {
            await container.replaceContent(content)
            await NSAnimationContext.runAnimationGroup { _ in
                inspectorItem.animator().isCollapsed = false
                splitView.animator().setPosition(width, ofDividerAt: 2)
            }
            inspectorItem.canCollapse = false
        }
    }
}

private class SplitContainer: NSViewController, Sendable {
    func replaceContent(_ content: NSViewController?) async {
        await NSAnimationContext.runAnimationGroup { _ in
            view.animator().alphaValue = 0
        }
        children.forEach { $0.removeFromParent() }
        view.subviews.forEach { $0.removeFromSuperview() }
        guard let content else {
            return
        }
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

private extension NSSplitViewItem {
    var container: SplitContainer {
        // swiftlint:disable:next force_cast
        viewController as! SplitContainer
    }
}
