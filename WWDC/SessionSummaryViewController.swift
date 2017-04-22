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
    
    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 24)
        l.textColor = .primaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        
        return l
    }()
    
    private lazy var summaryLabel: WWDCTextField = {
        let l = WWDCTextField(wrappingLabelWithString: "")
        l.font = NSFont.systemFont(ofSize: 18)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .dark

        return l
    }()
    
    private lazy var contextLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 16)
        l.textColor = .tertiaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        
        return l
    }()
    
    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.titleLabel, self.summaryLabel, self.contextLabel])
        
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 24
        v.translatesAutoresizingMaskIntoConstraints = false
        
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
        
        let title = viewModel.asObservable().ignoreNil().map({ $0.title })
        let summary = viewModel.asObservable().ignoreNil().map({ $0.summary })
        let footer = viewModel.asObservable().ignoreNil().map({ $0.footer })
        
        title.asDriver(onErrorJustReturn: "").drive(titleLabel.rx.text).addDisposableTo(self.disposeBag)
        summary.asDriver(onErrorJustReturn: "").drive(summaryLabel.rx.text).addDisposableTo(self.disposeBag)
        footer.asDriver(onErrorJustReturn: "").drive(contextLabel.rx.text).addDisposableTo(self.disposeBag)
    }
    
}
