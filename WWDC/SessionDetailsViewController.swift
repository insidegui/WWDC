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
    
    var viewModel = Variable<SessionViewModel?>(nil)
    
    let playerController: VideoPlayerViewController
    let summaryController: SessionSummaryViewController
    
    init() {
        self.playerController = VideoPlayerViewController()
        self.summaryController = SessionSummaryViewController()
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.playerController.view, self.summaryController.view])
        
        v.orientation = .vertical
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alignment = .leading
        v.distribution = .fill
        v.spacing = 22
        
        return v
    }()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        
        stackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 800).isActive = true
        
        view.addSubview(stackView)
        stackView.setContentHuggingPriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        view.setContentHuggingPriority(NSLayoutPriorityDefaultLow, for: .horizontal)
        stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46).isActive = true
        stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46).isActive = true
        stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 2).isActive = true
        stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -46).isActive = true
        
        viewModel.asObservable().bind(to: summaryController.viewModel).addDisposableTo(self.disposeBag)
    }
    
}
