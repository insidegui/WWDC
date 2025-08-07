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
class SplitViewController: NSViewController, WWDCTabController {
    init(exploreViewModel: NewExploreViewModel, scheduleViewModel: SessionListViewModel, videosViewModel: SessionListViewModel) {
        self.exploreViewModel = exploreViewModel
        self.scheduleViewModel = scheduleViewModel
        self.videosViewModel = videosViewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    typealias Tab = MainWindowTab
    let exploreViewModel: NewExploreViewModel
    let scheduleViewModel: SessionListViewModel
    let videosViewModel: SessionListViewModel

    @Published var activeTab: Tab = .explore {
        didSet {
            switchContent()
        }
    }

    var activeTabPublisher: AnyPublisher<Tab, Never> {
        $activeTab.eraseToAnyPublisher()
    }

    private var loadingView: ModalLoadingView?

    func showLoading() {
        loadingView = ModalLoadingView.show(attachedTo: view)
    }

    func hideLoading() {
        loadingView?.hide()
        loadingView = nil
    }

    private lazy var explore = NSHostingView(rootView: ExploreView(viewModel: exploreViewModel))
    private lazy var schedule = NSHostingView(rootView: SessionListContentView(viewModel: scheduleViewModel))
    private lazy var videos = NSHostingView(rootView: SessionListContentView(viewModel: videosViewModel))

    override func viewDidLoad() {
        super.viewDidLoad()
        switchContent()
    }

    private var currentContent: NSView?
    private func switchContent(duration: Double = 0.3) {
        guard viewIfLoaded != nil else {
            return
        }
        let newContent: NSView = {
            switch activeTab {
            case .explore: return explore
            case .schedule: return schedule
            case .videos: return videos
            }
        }()

        guard currentContent != newContent else {
            return
        }
        let newView = newContent
        let oldView = currentContent

        newView.alphaValue = 0
        newView.isHidden = false

        // Add the new view if not already in the container
        if newView.superview == nil {
            add(content: newView)
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // Animate out the old view
            oldView?.animator().alphaValue = 0

            // Animate in the new view
            newView.animator().alphaValue = 1

        }, completionHandler: {
            oldView?.removeFromSuperview()
            self.currentContent = newView
        })
    }

    private func add(content: NSView) {
        view.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

@available(macOS 26.0, *)
private struct ExploreView: View {
    @Bindable var viewModel: NewExploreViewModel
    var body: some View {
        NavigationSplitView {
            NewExploreCategoryList(viewModel: viewModel)
        } detail: {
            NewExploreTabDetailView(viewModel: viewModel)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

@available(macOS 26.0, *)
private struct SessionListContentView: View {
    @Bindable var viewModel: SessionListViewModel
    var body: some View {
        NavigationSplitView {
            SessionListView(viewModel: viewModel)
        } detail: {
            Text("Select a session to see more information.")
        }
        .navigationSplitViewStyle(.balanced)
    }
}
