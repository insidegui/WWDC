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
    
    let shelfController: ShelfViewController
    let summaryController: SessionSummaryViewController
    
    init() {
        self.shelfController = ShelfViewController()
        self.summaryController = SessionSummaryViewController()
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        
        view.widthAnchor.constraint(greaterThanOrEqualToConstant: 760).isActive = true
        
        shelfController.view.translatesAutoresizingMaskIntoConstraints = false
        summaryController.view.translatesAutoresizingMaskIntoConstraints = false
        
        shelfController.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 450).isActive = true
        
        view.addSubview(shelfController.view)
        view.addSubview(summaryController.view)
        
        shelfController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46).isActive = true
        shelfController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46).isActive = true
        shelfController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 2).isActive = true
        
        summaryController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 46).isActive = true
        summaryController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -46).isActive = true
        summaryController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -46).isActive = true
        
        shelfController.view.bottomAnchor.constraint(equalTo: summaryController.view.topAnchor, constant: -22).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.asObservable().bind(to: shelfController.viewModel).addDisposableTo(self.disposeBag)
        viewModel.asObservable().bind(to: summaryController.viewModel).addDisposableTo(self.disposeBag)
    }
    
}
