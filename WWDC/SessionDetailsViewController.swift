//
//  SessionDetailsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI
import ConfUIFoundation
import Combine

final class SessionDetailsViewController: WWDCWindowContentViewController {

    enum Tab: Int, WWDCTab, CaseIterable {
        case overview
        case transcript
        case chapters
    }

    private struct Metrics {
        static let padding: CGFloat = 46
        static let minShelfHeight: CGFloat = 280
    }

    var viewModel: SessionViewModel? {
        didSet {
            view.animator().alphaValue = (viewModel == nil) ? 0 : 1

            shelfController.viewModel = viewModel
            summaryController.viewModel = viewModel
            transcriptController.viewModel = viewModel

            guard let viewModel = viewModel else {
                return
            }

            if viewModel.identifier != oldValue?.identifier {
                tabController.selectedTab = .overview
            }

            transcriptButton.isHidden = (viewModel.session.transcript() == nil)
            chaptersButton.isHidden = viewModel.session.chapters.isEmpty

            let shouldHideButtonsBar = tabButtons.suffix(3).allSatisfy(\.isHidden)
            menuButtonsContainer.isHidden = shouldHideButtonsBar
        }
    }

    private lazy var overviewButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Overview"
        b.state = .on
        b.target = self
        b.action = #selector(tabButtonAction)
        b.tag = Tab.overview.rawValue

        return b
    }()

    private lazy var transcriptButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Transcript"
        b.state = .off
        b.target = self
        b.action = #selector(tabButtonAction)
        b.isHidden = true
        b.tag = Tab.transcript.rawValue

        return b
    }()

    private lazy var chaptersButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Chapters"
        b.state = .off
        b.target = self
        b.action = #selector(tabButtonAction)
        b.tag = Tab.chapters.rawValue

        return b
    }()

    private lazy var buttonsStackView: NSStackView = {
        let v = NSStackView(views: [
            self.overviewButton,
            self.transcriptButton,
            self.chaptersButton
            ])

        v.orientation = .horizontal
        v.alignment = .top
        v.spacing = 40

        return v
    }()

    private lazy var menuButtonsContainer: WWDCBottomBorderView = {
        let v = WWDCBottomBorderView()

        v.isHidden = true
        v.wantsLayer = true

        v.addSubview(self.buttonsStackView)

        NSLayoutConstraint.activate([
            v.heightAnchor.constraint(equalToConstant: 36),
            buttonsStackView.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            buttonsStackView.centerXAnchor.constraint(equalTo: v.centerXAnchor)
        ])

        return v
    }()

    private lazy var tabController: SessionDetailsTabController<Tab> = {
        let v = SessionDetailsTabController<Tab>(tabs: [
            .overview: summaryController,
            .transcript: transcriptController,
            .chapters: chaptersController
        ])

        return v
    }()

    let shelfController: ShelfViewController
    let summaryController: SessionSummaryViewController
    let transcriptController: SessionTranscriptViewController
    let chaptersController: NSViewController

    init() {
        shelfController = ShelfViewController()
        summaryController = SessionSummaryViewController()
        transcriptController = SessionTranscriptViewController()
        chaptersController = NSHostingController(rootView: ChaptersView())

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var cancellables = Set<AnyCancellable>()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true

        addChild(shelfController)
        addChild(tabController)

        shelfController.view.translatesAutoresizingMaskIntoConstraints = false
        tabController.view.translatesAutoresizingMaskIntoConstraints = false
        menuButtonsContainer.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(shelfController.view)
        view.addSubview(tabController.view)
        view.addSubview(menuButtonsContainer)

        shelfController.view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        let shelfMinHeightConstraint = shelfController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: Metrics.minShelfHeight)
        shelfMinHeightConstraint.priority = NSLayoutConstraint.Priority(rawValue: 999)

        NSLayoutConstraint.activate([
            shelfMinHeightConstraint,
            shelfController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.padding),
            shelfController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.padding),
            shelfController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Metrics.padding),
            menuButtonsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            menuButtonsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            menuButtonsContainer.topAnchor.constraint(equalTo: shelfController.view.bottomAnchor, constant: Metrics.padding * 0.5),
            tabController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.padding),
            tabController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.padding),
            tabController.view.topAnchor.constraint(equalTo: menuButtonsContainer.bottomAnchor, constant: Metrics.padding),
            tabController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Metrics.padding)
        ])

        tabController.$selectedTab.removeDuplicates().sink { [weak self] tab in
            guard let self else { return }
            updateTabSelection(with: tab)
        }
        .store(in: &cancellables)
    }

    private lazy var tabButtons = [overviewButton, transcriptButton, chaptersButton]

    private func updateTabSelection(with tab: Tab) {
        tabButtons.forEach {
            $0.state = $0.tag == tab.rawValue ? .on : .off
        }
    }

    @objc private func tabButtonAction(_ sender: WWDCTextButton) {
        guard let tab = Tab(rawValue: sender.tag) else {
            assertionFailure("Invalid tab \(sender.tag)")
            return
        }
        tabController.selectedTab = tab
    }

}

struct ChaptersView: View {
    var body: some View {
        Text("Chapters Here")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab Controller

private final class SessionDetailsTabController<Tab: RawRepresentable & CaseIterable & Hashable>: NSTabViewController where Tab.RawValue == Int {
    @Published
    var selectedTab = Tab.allCases.first! {
        didSet {
            guard selectedTab != oldValue, !isUpdatingSelectedTab else { return }
            
            guard let index = tabViewItems.compactMap({ $0.identifier as? Tab }).firstIndex(of: selectedTab) else {
                assertionFailure("Couldn't find index for tab \(selectedTab)")
                return
            }

            self.selectedTabViewItemIndex = index
        }
    }

    init(tabs: [Tab: NSViewController]) {
        super.init(nibName: nil, bundle: nil)

        tabStyle = .unspecified

        install(tabs)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func install(_ tabs: [Tab: NSViewController]) {
        for tab in tabs.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let item = NSTabViewItem(viewController: tabs[tab]!)
            item.identifier = tab
            self.addTabViewItem(item)
        }
    }

    private var isUpdatingSelectedTab = false

    override var selectedTabViewItemIndex: Int {
        didSet {
            guard selectedTabViewItemIndex != oldValue else { return }
            guard selectedTabViewItemIndex >= 0 && selectedTabViewItemIndex < tabViewItems.count else { return }

            guard let tab = Tab(rawValue: selectedTabViewItemIndex) else {
                assertionFailure("selectedTabViewItemIndex of \(selectedTabViewItemIndex) doesn't correspond to a valid tab item")
                return
            }

            isUpdatingSelectedTab = true

            selectedTab = tab

            isUpdatingSelectedTab = false
        }
    }
}

extension NSLayoutConstraint {
    func withPriority(_ priority: Priority) -> Self {
        self.priority = priority
        return self
    }
}
