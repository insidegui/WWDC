//
//  SessionSummaryViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import Combine
import SwiftUI

class SessionSummaryViewController: NSViewController {

    private var cancellables: Set<AnyCancellable> = []

    var viewModel: SessionViewModel? {
        didSet {
            updateBindings()
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum Metrics {
        static let summaryHeight: CGFloat = 100
    }

    private lazy var titleLabel: WWDCTextField = {
        let l = WWDCTextField(labelWithString: "")
        l.cell?.backgroundStyle = .emphasized
        l.lineBreakMode = .byWordWrapping
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.allowsDefaultTighteningForTruncation = true
        l.maximumNumberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isSelectable = true
        l.allowsEditingTextAttributes = true

        return l
    }()

    lazy var actionsViewModel = SessionActionsViewModel()
    
    private lazy var actionsHostingView: NSHostingView<SessionActionsView> = {
        let view = SessionActionsView(viewModel: actionsViewModel)
        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.isHidden = true
        return hostingView
    }()

    lazy var relatedSessionsViewModel = RelatedSessionsViewModel()

    private lazy var relatedSessionsHostingView: NSHostingView<RelatedSessionsView> = {
        let view = RelatedSessionsView(viewModel: relatedSessionsViewModel)
        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        return hostingView
    }()

    private func attributedSummaryString(from string: String) -> NSAttributedString {
        .create(with: string, font: .systemFont(ofSize: 15), color: .secondaryText, lineHeightMultiple: 1.2)
    }

    private lazy var summaryTextView: NSTextView = {
        let v = NSTextView()

        v.drawsBackground = false
        v.backgroundColor = .clear
        v.autoresizingMask = [.width]
        v.textContainer?.widthTracksTextView = true
        v.textContainer?.heightTracksTextView = false
        v.isEditable = false
        v.isVerticallyResizable = true
        v.isHorizontallyResizable = false
        v.textContainer?.containerSize = NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude)

        return v
    }()

    private lazy var summaryScrollView: NSScrollView = {
        let v = NSScrollView()

        v.contentView = FlippedClipView()
        v.drawsBackground = false
        v.backgroundColor = .clear
        v.borderType = .noBorder
        v.documentView = self.summaryTextView
        v.autohidesScrollers = true
        v.hasVerticalScroller = true
        v.hasHorizontalScroller = false
        v.verticalScrollElasticity = .none

        return v
    }()

    private lazy var contextLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 16)
        l.textColor = .tertiaryText
        l.cell?.backgroundStyle = .emphasized
        l.lineBreakMode = .byTruncatingTail
        l.allowsDefaultTighteningForTruncation = true

        return l
    }()

    private lazy var actionLinkLabel: ActionLabel = {
        let l = ActionLabel(labelWithString: "")

        l.font = .systemFont(ofSize: 16)
        l.textColor = .primary
        l.target = self
        l.action = #selector(clickedActionLabel)

        return l
    }()

    private lazy var contextStackView: NSStackView = {
        let v = NSStackView(views: [self.contextLabel, self.actionLinkLabel])

        v.orientation = .horizontal
        v.alignment = .top
        v.distribution = .fillProportionally
        v.spacing = 16
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.summaryScrollView, self.contextStackView])

        v.orientation = .vertical
        v.alignment = .leading
        v.distribution = .fill
        v.spacing = 24
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height / 2))
        view.wantsLayer = true

        view.addSubview(titleLabel)
        view.addSubview(actionsHostingView)
        view.addSubview(stackView)

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        actionsHostingView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor).isActive = true
        actionsHostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionsHostingView.leadingAnchor, constant: -24).isActive = true
        titleLabel.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24).isActive = true

        stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        summaryScrollView.heightAnchor.constraint(equalToConstant: Metrics.summaryHeight).isActive = true

        stackView.addArrangedSubview(relatedSessionsHostingView)
        relatedSessionsHostingView.heightAnchor.constraint(equalToConstant: RelatedSessionsView.Metrics.height).isActive = true
        relatedSessionsHostingView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
        relatedSessionsHostingView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateBindings()
    }

    private func updateBindings() {
        actionsHostingView.isHidden = (viewModel == nil)
        actionsViewModel.viewModel = viewModel
        self.summaryScrollView.scroll(.zero)

        guard let viewModel = viewModel else { return }

        cancellables = []

        viewModel
            .rxTitle
            .replaceError(with: "")
            .map(NSAttributedString.attributedBoldTitle(with:))
            .driveUI(\.attributedStringValue, on: titleLabel)
            .store(in: &cancellables)
        viewModel.rxFooter.replaceError(with: "").driveUI(\.stringValue, on: contextLabel).store(in: &cancellables)

        viewModel.rxSummary.driveUI { [weak self] summary in
            guard let self = self else { return }
            guard let textStorage = self.summaryTextView.textStorage else { return }
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.replaceCharacters(in: range, with: self.attributedSummaryString(from: summary))
        }
        .store(in: &cancellables)

        viewModel.rxRelatedSessions.driveUI { [weak self] relatedResources in
            let relatedSessions = relatedResources.compactMap({ $0.session })
            self?.relatedSessionsViewModel.sessions = relatedSessions.compactMap(SessionViewModel.init)
        }
        .store(in: &cancellables)

        // https://github.com/insidegui/WWDC/issues/724
        // I believe this is a dead feature, it appears to have been showing a link to sign up for a lab.
        // The API has since been updated, we could restore the feature because there's other data available now.
        viewModel.rxActionPrompt.replaceNilAndError(with: "").driveUI(\.stringValue, on: actionLinkLabel).store(in: &cancellables)
    }

    @objc private func clickedActionLabel() {
        guard let url = viewModel?.actionLinkURL else { return }

        NSWorkspace.shared.open(url)
    }

}

struct SessionSummaryViewControllerWrapper: NSViewControllerRepresentable {
    let controller: SessionSummaryViewController

    func makeNSViewController(context: Context) -> SessionSummaryViewController {
        return controller
    }

    func updateNSViewController(_ nsViewController: SessionSummaryViewController, context: Context) {
        // No updates needed - controller manages its own state
    }
}
