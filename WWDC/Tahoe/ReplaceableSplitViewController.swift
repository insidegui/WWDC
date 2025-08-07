//
//  ReplaceableSplitViewController.swift
//  WWDC
//
//  Created by luca on 30.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import Combine
import SwiftUI

@available(macOS 26.0, *)
class ReplaceableSplitViewController: NSSplitViewController, WWDCTabController {
    typealias Tab = MainWindowTab
    let exploreViewModel: NewExploreViewModel
    let scheduleViewModel: SessionListViewModel
    let videosViewModel: SessionListViewModel
    @Published var activeTab: Tab = .explore {
        didSet {
            guard activeTab != oldValue else {
                return
            }
            changeContent()
            NSAnimationContext.runAnimationGroup { _ in
                topSegmentControl?.animator().selectedSegment = activeTab.rawValue
            }
        }
    }

    var activeTabPublisher: AnyPublisher<Tab, Never> {
        $activeTab.eraseToAnyPublisher()
    }

    fileprivate var sidebarItem: NSSplitViewItem!
    fileprivate var detailItem: NSSplitViewItem!

    private var previousSidebarWidth: CGFloat?
    private weak var windowController: WWDCWindowControllerObject?

    init(windowController: WWDCWindowControllerObject, exploreViewModel: NewExploreViewModel, scheduleViewModel: SessionListViewModel, videosViewModel: SessionListViewModel) {
        self.windowController = windowController
        self.exploreViewModel = exploreViewModel
        self.scheduleViewModel = scheduleViewModel
        self.videosViewModel = videosViewModel
        super.init(nibName: nil, bundle: nil)
        sidebarItem = NSSplitViewItem(sidebarWithViewController: SplitContainer(nibName: nil, bundle: nil))
        sidebarItem.container.isSidebar = true
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)
        detailItem = NSSplitViewItem(viewController: SplitContainer(nibName: nil, bundle: nil))
        detailItem.automaticallyAdjustsSafeAreaInsets = true
        addSplitViewItem(detailItem)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        changeContent()
    }

    private func changeContent() {
        let sidebarContent: NSView = {
            switch activeTab {
            case .explore: return NSHostingView(rootView: NewExploreCategoryList(viewModel: exploreViewModel))
            case .schedule: return NSHostingView(rootView: SessionListView(viewModel: scheduleViewModel))
            case .videos: return NSHostingView(rootView: SessionListView(viewModel: videosViewModel))
            }
        }()
        let sidebarContainer = sidebarItem.container
        Task {
            await sidebarContainer.replaceContent(sidebarContent)
        }

        let detailContent: NSView = {
            switch activeTab {
            case .explore: return NSHostingView(rootView: NewExploreTabDetailView(viewModel: exploreViewModel))
            case .schedule: return NSHostingView(rootView: NewSessionDetailWrapperView(viewModel: scheduleViewModel))
            case .videos: return NSHostingView(rootView: NewSessionDetailWrapperView(viewModel: videosViewModel))
            }
        }()
        let detailContainer = detailItem.container
        Task {
            await detailContainer.replaceContent(detailContent)
        }
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        guard sidebarItem.isCollapsed == false else { return }
        previousSidebarWidth = splitView.arrangedSubviews[0].bounds.width
    }
}

private class SplitContainer: NSViewController, Sendable {
    var isSidebar = false
    override func loadView() {
        super.loadView()
        guard isSidebar else {
            return
        }
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: Constants.sidebarWidth),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.minimumWindowHeight)
        ])
    }

    func replaceContent(_ content: NSView) async {
        await NSAnimationContext.runAnimationGroup { _ in
            view.animator().alphaValue = 0
        }
        view.subviews.forEach { $0.removeFromSuperview() }
        view.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
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
