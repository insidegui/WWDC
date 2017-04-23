//
//  VideoPlayerViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

class VideoPlayerViewController: NSViewController {

    private let disposeBag = DisposeBag()
    
    var viewModel = Variable<SessionViewModel?>(nil)
    
    lazy var shelfView: ShelfView = {
        let v = ShelfView()
        
        v.translatesAutoresizingMaskIntoConstraints = false
        
        return v
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height / 2))
        view.wantsLayer = true
        
        view.addSubview(shelfView)
        shelfView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        shelfView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        shelfView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        shelfView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.asObservable().subscribe(onNext: { [weak self] viewModel in
            guard let viewModel = viewModel else { return }
            
            if let imageUrl = viewModel.imageUrl {
                ImageCache.shared.fetchImage(at: imageUrl) { url, image in
                    guard url == imageUrl else { return }
                    
                    self?.shelfView.image = image
                }
            }
        }).addDisposableTo(self.disposeBag)
    }
    
}
