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

class SessionSummaryViewController: NSViewController {

    private let disposeBag = DisposeBag()
    
    var viewModel = Variable<SessionViewModel?>(nil)
    
    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var titleLabel: WWDCTextField = {
        let l = WWDCTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 24)
        l.textColor = .primaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byWordWrapping
        l.setContentCompressionResistancePriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        l.allowsDefaultTighteningForTruncation = true
        l.maximumNumberOfLines = 2
        
        return l
    }()
    
    lazy var actionsViewController: SessionActionsViewController = {
        let v = SessionActionsViewController()
        
        v.view.isHidden = true
        
        return v
    }()
    
    private lazy var titleStack: NSStackView = {
        let v = NSStackView(views: [self.titleLabel, self.actionsViewController.view])
        
        v.orientation = .horizontal
        v.alignment = .top
        v.distribution = .fill
        v.spacing = 22
        v.translatesAutoresizingMaskIntoConstraints = false
        
        return v
    }()
    
    private lazy var summaryLabel: WWDCTextField = {
        let l = WWDCTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 18)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .dark
        l.isSelectable = true
        l.lineBreakMode = .byWordWrapping
        l.setContentCompressionResistancePriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        l.allowsDefaultTighteningForTruncation = true
        l.maximumNumberOfLines = 5
        
        return l
    }()
    
    private lazy var contextLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 16)
        l.textColor = .tertiaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        l.allowsDefaultTighteningForTruncation = true
        
        return l
    }()
    
    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.titleStack, self.summaryLabel, self.contextLabel])
        
        v.orientation = .vertical
        v.alignment = .leading
        v.distribution = .fill
        v.spacing = 24
        v.translatesAutoresizingMaskIntoConstraints = false
        
        self.titleStack.leadingAnchor.constraint(equalTo: v.leadingAnchor).isActive = true
        self.titleStack.trailingAnchor.constraint(equalTo: v.trailingAnchor).isActive = true
        
        return v
    }()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height / 2))
        view.wantsLayer = true
        
        view.addSubview(stackView)
        stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.asObservable().map({ $0 == nil }).bind(to: actionsViewController.view.rx.isHidden).addDisposableTo(self.disposeBag)
        
        let title = viewModel.asObservable().ignoreNil().flatMap({ $0.rxTitle })
        let summary = viewModel.asObservable().ignoreNil().flatMap({ $0.rxSummary })
        let footer = viewModel.asObservable().ignoreNil().flatMap({ $0.rxFooter })
        
        title.asDriver(onErrorJustReturn: "").drive(titleLabel.rx.text).addDisposableTo(self.disposeBag)
        summary.asDriver(onErrorJustReturn: "").drive(summaryLabel.rx.text).addDisposableTo(self.disposeBag)
        footer.asDriver(onErrorJustReturn: "").drive(contextLabel.rx.text).addDisposableTo(self.disposeBag)
        
        viewModel.asObservable().bind(to: actionsViewController.viewModel).addDisposableTo(self.disposeBag)
    }
    
}
