//
//  SessionActionsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import PlayerUI
import ConfCore
import RxSwift
import RxCocoa

protocol SessionActionsViewControllerDelegate: class {
    
    func sessionActionsDidSelectFavorite(_ sender: NSView?)
    func sessionActionsDidSelectDownload(_ sender: NSView?)
    func sessionActionsDidSelectShare(_ sender: NSView?)
    
}

class SessionActionsViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let disposeBag = DisposeBag()
    
    var viewModel = Variable<SessionViewModel?>(nil)
    
    weak var delegate: SessionActionsViewControllerDelegate?
    
    private lazy var favoriteButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = #imageLiteral(resourceName: "favorite")
        b.target = self
        b.action = #selector(toggleFavorite(_:))
        b.isToggle = true
        
        return b
    }()
    
    private lazy var downloadButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = #imageLiteral(resourceName: "download")
        b.target = self
        b.action = #selector(download(_:))
        
        return b
    }()
    
    private lazy var shareButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = #imageLiteral(resourceName: "share")
        b.target = self
        b.action = #selector(share(_:))
        
        return b
    }()
    
    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.favoriteButton, self.downloadButton, self.shareButton])
        
        v.orientation = .horizontal
        v.spacing = 22
        v.alignment = .centerY
        v.distribution = .equalSpacing
        v.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        
        return v
    }()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 122, height: 28))
        view.wantsLayer = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 122).isActive = true
        view.heightAnchor.constraint(equalToConstant: 28).isActive = true
        
        stackView.frame = view.bounds
        view.addSubview(stackView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.asObservable().observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] viewModel in
            guard let viewModel = viewModel else { return }
            
            self?.favoriteButton.state = viewModel.isFavorite ? NSOnState : NSOffState
        }).addDisposableTo(self.disposeBag)
    }
    
    @IBAction func toggleFavorite(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectFavorite(sender)
    }
    
    @IBAction func download(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectDownload(sender)
    }
    
    @IBAction func share(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectShare(sender)
    }
    
}
