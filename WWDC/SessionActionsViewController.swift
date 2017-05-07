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
    
    private lazy var downloadIndicator: NSProgressIndicator = {
        let pi = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        
        pi.style = .spinningStyle
        pi.isIndeterminate = false
        pi.minValue = 0
        pi.maxValue = 1
        pi.doubleValue = 0
        pi.translatesAutoresizingMaskIntoConstraints = false
        pi.widthAnchor.constraint(equalToConstant: 24).isActive = true
        pi.heightAnchor.constraint(equalToConstant: 24).isActive = true
        pi.isHidden = true
        
        return pi
    }()
    
    private lazy var shareButton: PUIButton = {
        let b = PUIButton(frame: .zero)
        
        b.image = #imageLiteral(resourceName: "share")
        b.target = self
        b.action = #selector(share(_:))
        
        return b
    }()
    
    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.favoriteButton, self.downloadButton, self.downloadIndicator, self.shareButton])
        
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
        
        let isFavorite = viewModel.asObservable().ignoreNil().flatMap({ $0.rxIsFavorite })
        let validDownload = viewModel.asObservable().ignoreNil().flatMap({ $0.rxValidDownload })
        
        isFavorite.observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] fave in
            self.favoriteButton.state = fave ? NSOnState : NSOffState
        }).addDisposableTo(self.disposeBag)
        
        validDownload.observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] download in
            guard let download = download else {
                self.downloadIndicator.isHidden = true
                self.downloadButton.isHidden = false
                return
            }
            
            switch download.status {
            case .downloading:
                self.downloadIndicator.isHidden = false
                self.downloadButton.isHidden = true
                self.downloadIndicator.doubleValue = download.progress
            case .completed:
                self.downloadIndicator.isHidden = true
                self.downloadButton.isHidden = false
            default:
                // TODO: handle other download statuses
                print("Download status not handled: \(download.status)")
            }
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
