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

    private lazy var titleLabel: WWDCTextField = {
        let l = WWDCTextField(labelWithString: "")
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byWordWrapping
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.allowsDefaultTighteningForTruncation = true
        l.maximumNumberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false

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

    private lazy var summaryLabel: WWDCTextField = {
        let l = WWDCTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 18)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .dark
        l.isSelectable = true
        l.lineBreakMode = .byWordWrapping
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.allowsDefaultTighteningForTruncation = true
        l.maximumNumberOfLines = 5

        return l
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

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.summaryLabel, self.contextLabel])

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

        addChildViewController(relatedSessionsViewController)
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

        guard let viewModel = viewModel else { return }

        disposeBag = DisposeBag()

        viewModel.rxTitle.map(NSAttributedString.attributedBoldTitle(with:)).subscribe(onNext: { [weak self] title in
            self?.titleLabel.attributedStringValue = title
        }).disposed(by: disposeBag)
        viewModel.rxSummary.bind(to: summaryLabel.rx.text).disposed(by: disposeBag)
        viewModel.rxFooter.bind(to: contextLabel.rx.text).disposed(by: disposeBag)

        viewModel.rxRelatedSessions.subscribe(onNext: { [weak self] relatedResources in
            let relatedSessions = relatedResources.compactMap({ $0.session })
            self?.relatedSessionsViewController.sessions = relatedSessions.compactMap(SessionViewModel.init)
        }).disposed(by: disposeBag)

        relatedSessionsViewController.scrollToBeginningOfDocument(nil)
    }

}
