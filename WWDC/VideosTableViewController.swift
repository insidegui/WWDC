//
//  VideosTableViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import RealmSwift
import ConfCore

class VideosTableViewController: NSViewController {
    
    private let disposeBag = DisposeBag()
    
    var sessions = Variable<Results<Session>?>(nil)
    
    var viewModels: [SessionViewModel] = [] {
        didSet {
            print(viewModels)
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.blue.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sessions.asObservable().subscribe(onNext: { [weak self] results in
            guard let results = results else { return }
            
            self?.viewModels = results.flatMap({ SessionViewModel(session: $0) })
        }).addDisposableTo(self.disposeBag)
    }
    
}
