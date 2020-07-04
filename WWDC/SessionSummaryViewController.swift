//
//  SessionSummaryViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import ConfCore

class SessionSummaryViewController: NSViewController {

    private var disposeBag = DisposeBag()

    var viewModel: SessionViewModel? = nil {
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
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byWordWrapping
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.allowsDefaultTighteningForTruncation = true
        l.maximumNumberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isSelectable = true
        l.allowsEditingTextAttributes = true

        return l
    }()

    lazy var actionsViewController: SessionActionsViewController = {
        let v = SessionActionsViewController()

        v.view.isHidden = true
        v.view.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    lazy var relatedSessionsViewController: RelatedSessionsViewController = {
        let c = RelatedSessionsViewController()

        c.title = "Related Sessions"

        return c
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
        l.cell?.backgroundStyle = .dark
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
        view.addSubview(actionsViewController.view)
        view.addSubview(stackView)

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        actionsViewController.view.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor).isActive = true
        actionsViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionsViewController.view.leadingAnchor, constant: -24).isActive = true
        titleLabel.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24).isActive = true

        stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        summaryScrollView.heightAnchor.constraint(equalToConstant: Metrics.summaryHeight).isActive = true

        addChild(relatedSessionsViewController)
        relatedSessionsViewController.view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(relatedSessionsViewController.view)
        relatedSessionsViewController.view.heightAnchor.constraint(equalToConstant: RelatedSessionsViewController.Metrics.height).isActive = true
        relatedSessionsViewController.view.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
        relatedSessionsViewController.view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateBindings()
    }

    private func updateBindings() {
        actionsViewController.view.isHidden = (viewModel == nil)
        actionsViewController.viewModel = viewModel
        self.summaryScrollView.scroll(.zero)

        guard let viewModel = viewModel else { return }

        disposeBag = DisposeBag()

        viewModel.rxTitle.map(NSAttributedString.attributedBoldTitle(with:)).subscribe(onNext: { [weak self] title in
            self?.titleLabel.attributedStringValue = title
        }).disposed(by: disposeBag)
        viewModel.rxFooter.bind(to: contextLabel.rx.text).disposed(by: disposeBag)

        viewModel.rxSummary.subscribe(onNext: { [weak self] summary in
            guard let self = self else { return }
            guard let textStorage = self.summaryTextView.textStorage else { return }
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.replaceCharacters(in: range, with: self.attributedSummaryString(from: summary))
        }).disposed(by: disposeBag)

        viewModel.rxRelatedSessions.subscribe(onNext: { [weak self] relatedResources in
            let relatedSessions = relatedResources.compactMap({ $0.session })
            self?.relatedSessionsViewController.sessions = relatedSessions.compactMap(SessionViewModel.init)
        }).disposed(by: disposeBag)

        relatedSessionsViewController.scrollToBeginningOfDocument(nil)

        viewModel.rxActionPrompt.bind(to: actionLinkLabel.rx.text).disposed(by: disposeBag)
    }

    @objc private func clickedActionLabel() {
        guard let url = viewModel?.actionLinkURL else { return }

        NSWorkspace.shared.open(url)
    }

}
