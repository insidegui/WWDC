//
//  SessionDetailsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

class SessionDetailsViewController: NSViewController {

    private let disposeBag = DisposeBag()

    let listStyle: SessionsListStyle

    var viewModel: SessionViewModel? = nil {
        didSet {

            informationStackView.animator().isHidden = (viewModel == nil)
            shelfController.view.animator().isHidden = (viewModel == nil)

            shelfController.viewModel = viewModel
            summaryController.viewModel = viewModel
            transcriptController.viewModel = viewModel

            guard let viewModel = viewModel else {
                return
            }

            if viewModel.identifier != oldValue?.identifier {

                showOverview()
            }

            transcriptButton.isHidden = (viewModel.session.transcript() == nil)

            let shouldHideButtonsBar = transcriptButton.isHidden && bookmarksButton.isHidden
            menuButtonsContainer.isHidden = shouldHideButtonsBar

            let instance = viewModel.sessionInstance
            let type = instance.type

            let sessionHasNoVideo = (type == .lab || type == .getTogether) && !(instance.isCurrentlyLive == true)

            shelfController.view.isHidden = sessionHasNoVideo

            // Connect stack view (bottom half of screen), to the top of the view
            // or to the bottom of the video, if it's present
            if isViewLoaded {

                shelfBottomConstraint.isActive = !sessionHasNoVideo
                informationStackViewTopConstraint.isActive = sessionHasNoVideo
                informationStackViewBottomConstraint.isActive = !sessionHasNoVideo
            }
        }
    }

    private lazy var overviewButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Overview"
        b.state = NSOnState
        b.target = self
        b.action = #selector(tabButtonAction)

        return b
    }()

    private lazy var transcriptButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Transcript"
        b.state = NSOffState
        b.target = self
        b.action = #selector(tabButtonAction)
        b.isHidden = true

        return b
    }()

    private lazy var bookmarksButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Bookmarks"
        b.state = NSOffState
        b.target = self
        b.action = #selector(tabButtonAction)

        // TODO: enable bookmarks section
        b.isHidden = true

        return b
    }()

    private lazy var buttonsStackView: NSStackView = {
        let v = NSStackView(views: [
            self.overviewButton,
            self.transcriptButton,
            self.bookmarksButton
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

        v.heightAnchor.constraint(equalToConstant: 36).isActive = true

        v.addSubview(self.buttonsStackView)

        self.buttonsStackView.topAnchor.constraint(equalTo: v.topAnchor).isActive = true
        self.buttonsStackView.centerXAnchor.constraint(equalTo: v.centerXAnchor).isActive = true

        return v
    }()

    private lazy var tabContainer: SessionDetailsTabContainer = {
        let v = SessionDetailsTabContainer()

        v.wantsLayer = true
        v.setContentHuggingPriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        v.setContentHuggingPriority(NSLayoutPriorityDefaultLow, for: .vertical)

        return v
    }()

    private lazy var informationStackView: NSStackView = {
        let v = NSStackView(views: [self.menuButtonsContainer, self.tabContainer])

        v.orientation = .vertical
        v.spacing = 22
        v.alignment = .leading
        v.distribution = .fill
        v.edgeInsets = EdgeInsets(top: 18, left: 0, bottom: 0, right: 0)

        self.tabContainer.leadingAnchor.constraint(equalTo: v.leadingAnchor).isActive = true
        self.tabContainer.trailingAnchor.constraint(equalTo: v.trailingAnchor).isActive = true

        return v
    }()

    let shelfController: ShelfViewController
    let summaryController: SessionSummaryViewController
    let transcriptController: TranscriptTableViewController

    init(listStyle: SessionsListStyle) {
        self.listStyle = listStyle

        shelfController = ShelfViewController()
        summaryController = SessionSummaryViewController()
        transcriptController = TranscriptTableViewController()

        super.init(nibName: nil, bundle: nil)!
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var shelfBottomConstraint: NSLayoutConstraint = {
        return self.shelfController.view.bottomAnchor.constraint(equalTo: self.informationStackView.topAnchor)
    }()

    private lazy var informationStackViewTopConstraint: NSLayoutConstraint = {
        return self.informationStackView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 22)
    }()

    private lazy var informationStackViewBottomConstraint: NSLayoutConstraint = {
        return self.informationStackView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -46)
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true

        shelfController.view.translatesAutoresizingMaskIntoConstraints = false
        informationStackView.translatesAutoresizingMaskIntoConstraints = false

        let constraint = shelfController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
        constraint.priority = 999
        constraint.isActive = true

        shelfController.view.setContentCompressionResistancePriority(NSLayoutPriorityDefaultHigh, for: .vertical)

        view.addSubview(shelfController.view)
        view.addSubview(informationStackView)

        shelfController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46).isActive = true
        shelfController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46).isActive = true
        shelfController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 22).isActive = true

        informationStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46).isActive = true
        informationStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46).isActive = true
        informationStackViewBottomConstraint.isActive = true

        shelfBottomConstraint.isActive = true
        informationStackViewTopConstraint.isActive = false

        showOverview()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @objc private func tabButtonAction(_ sender: WWDCTextButton) {
        if sender == overviewButton {
            showOverview()
        } else if sender == transcriptButton {
            showTranscript()
        } else if sender == bookmarksButton {
            showBookmarks()
        }
    }

    func showOverview() {
        overviewButton.state = NSOnState
        transcriptButton.state = NSOffState
        bookmarksButton.state = NSOffState

        tabContainer.currentView = summaryController.view
    }

    func showTranscript() {
        transcriptButton.state = NSOnState
        overviewButton.state = NSOffState
        bookmarksButton.state = NSOffState

        tabContainer.currentView = transcriptController.view
    }

    func showBookmarks() {
        bookmarksButton.state = NSOnState
        overviewButton.state = NSOffState
        transcriptButton.state = NSOffState
    }
}

fileprivate class SessionDetailsTabContainer: NSView {

    var currentView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()

            if let newView = currentView {
                newView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
                newView.frame = frame

                addSubview(newView)
            }
        }
    }
}
