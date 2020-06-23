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

    private struct Metrics {
        static let padding: CGFloat = 46
    }

    private let disposeBag = DisposeBag()

    let listStyle: SessionsListStyle

    var viewModel: SessionViewModel? = nil {
        didSet {
            view.animator().alphaValue = (viewModel == nil) ? 0 : 1

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

            let sessionHasNoVideo = [.lab, .getTogether, .labByAppointment].contains(type) && !(instance.isCurrentlyLive == true)

            shelfController.view.isHidden = sessionHasNoVideo

            // It's worth noting that this condition will always be true since the view
            // gets loaded when add to the split view controller
            if isViewLoaded {
                // Connect stack view (bottom half of screen), to the top of the view
                // or to the bottom of the video, if it's present
                shelfBottomConstraint.isActive = !sessionHasNoVideo
                informationStackViewTopConstraint.isActive = sessionHasNoVideo
                informationStackViewBottomConstraint.isActive = !sessionHasNoVideo
            }
        }
    }

    private lazy var overviewButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Overview"
        b.state = .on
        b.target = self
        b.action = #selector(tabButtonAction)

        return b
    }()

    private lazy var transcriptButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Transcript"
        b.state = .off
        b.target = self
        b.action = #selector(tabButtonAction)
        b.isHidden = true

        return b
    }()

    private lazy var bookmarksButton: WWDCTextButton = {
        let b = WWDCTextButton()

        b.title = "Bookmarks"
        b.state = .off
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
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        v.setContentHuggingPriority(.defaultLow, for: .vertical)

        return v
    }()

    private lazy var informationStackView: NSStackView = {
        let v = NSStackView(views: [self.menuButtonsContainer, self.tabContainer])

        v.orientation = .vertical
        v.spacing = 22
        v.alignment = .leading
        v.distribution = .fill
        v.edgeInsets = NSEdgeInsets(top: 18, left: 0, bottom: 0, right: 0)

        self.tabContainer.leadingAnchor.constraint(equalTo: v.leadingAnchor).isActive = true
        self.tabContainer.trailingAnchor.constraint(equalTo: v.trailingAnchor).isActive = true

        return v
    }()

    let shelfController: ShelfViewController
    let summaryController: SessionSummaryViewController
    let transcriptController: SessionTranscriptViewController

    init(listStyle: SessionsListStyle) {
        self.listStyle = listStyle

        shelfController = ShelfViewController()
        summaryController = SessionSummaryViewController()
        transcriptController = SessionTranscriptViewController()

        super.init(nibName: nil, bundle: nil)
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
        return self.informationStackView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -Metrics.padding)
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true

        shelfController.view.translatesAutoresizingMaskIntoConstraints = false
        informationStackView.translatesAutoresizingMaskIntoConstraints = false

        let constraint = shelfController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
        constraint.priority = NSLayoutConstraint.Priority(rawValue: 999)
        constraint.isActive = true

        shelfController.view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        view.addSubview(shelfController.view)
        view.addSubview(informationStackView)

        shelfController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.padding).isActive = true
        shelfController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.padding).isActive = true
        shelfController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 22).isActive = true

        informationStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.padding).isActive = true
        informationStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.padding).isActive = true
        informationStackViewBottomConstraint.isActive = true

        shelfBottomConstraint.isActive = true
        informationStackViewTopConstraint.isActive = false

        showOverview()
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
        overviewButton.state = .on
        transcriptButton.state = .off
        bookmarksButton.state = .off

        tabContainer.currentView = summaryController.view
    }

    func showTranscript() {
        transcriptButton.state = .on
        overviewButton.state = .off
        bookmarksButton.state = .off

        tabContainer.currentView = transcriptController.view
    }

    func showBookmarks() {
        bookmarksButton.state = .on
        overviewButton.state = .off
        transcriptButton.state = .off
    }
}

private class SessionDetailsTabContainer: NSView {

    var currentView: NSView? {
        didSet {
            guard oldValue !== currentView else { return }

            oldValue?.removeFromSuperview()

            if let newView = currentView {
                newView.autoresizingMask = [.width, .height]
                newView.frame = frame

                addSubview(newView)
            }
        }
    }
}
