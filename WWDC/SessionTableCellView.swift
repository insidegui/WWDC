//
//  SessionTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

final class SessionTableCellView: NSTableCellView {
    
    private var disposeBag = DisposeBag()
    
    var viewModel: SessionViewModel? {
        didSet {
            guard viewModel != oldValue else { return }
            
            thumbnailImageView.image = #imageLiteral(resourceName: "noimage")
            
            bindUI()
        }
    }
    
    private var imageDownloadOperation: Operation? = nil
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        buildUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        imageDownloadOperation?.cancel()
        
        thumbnailImageView.image = #imageLiteral(resourceName: "noimage")
        
        self.disposeBag = DisposeBag()
    }
    
    private func bindUI() {
        guard let viewModel = viewModel else { return }
        
        viewModel.rxTitle.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(titleLabel.rx.text).addDisposableTo(self.disposeBag)
        viewModel.rxSubtitle.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(subtitleLabel.rx.text).addDisposableTo(self.disposeBag)
        viewModel.rxContext.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(contextLabel.rx.text).addDisposableTo(self.disposeBag)
        
        viewModel.rxIsLab.distinctUntilChanged().map({ !$0 }).bind(to: self.labIndicator.rx.isHidden).addDisposableTo(self.disposeBag)
        viewModel.rxIsLab.distinctUntilChanged().bind(to: self.thumbnailImageView.rx.isHidden).addDisposableTo(self.disposeBag)
        
        viewModel.rxImageUrl.distinctUntilChanged({ $0 != $1 }).subscribe(onNext: { [weak self] imageUrl in
            guard let imageUrl = imageUrl else { return }
            
            self?.imageDownloadOperation?.cancel()
            
            self?.imageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight) { [weak self] url, _, thumb in
                guard url == imageUrl else { return }
                
                self?.thumbnailImageView.image = thumb
            }
        }).addDisposableTo(self.disposeBag)
        
        viewModel.rxColor.distinctUntilChanged({ $0 == $1 }).subscribe(onNext: { [weak self] color in
            self?.contextColorView.color = color
        }).addDisposableTo(self.disposeBag)
        
        viewModel.rxDarkColor.distinctUntilChanged({ $0 == $1 }).subscribe(onNext: { [weak self] color in
            self?.labIndicator.backgroundColor = color
        }).addDisposableTo(self.disposeBag)
        
        viewModel.rxProgresses.subscribe(onNext: { [weak self] progresses in
            if let progress = progresses.first {
                self?.contextColorView.hasValidProgress = true
                self?.contextColorView.progress = progress.relativePosition
            } else {
                self?.contextColorView.hasValidProgress = false
                self?.contextColorView.progress = 0
            }
        }).addDisposableTo(self.disposeBag)
    }
    
    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 14)
        l.textColor = .primaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        
        return l
    }()
    
    private lazy var subtitleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 12)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        
        return l
    }()
    
    private lazy var contextLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 12)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        
        return l
    }()
    
    private lazy var thumbnailImageView: NSImageView = {
        let v = NSImageView()
        
        v.heightAnchor.constraint(equalToConstant: 48).isActive = true
        v.widthAnchor.constraint(equalToConstant: 85).isActive = true
        v.wantsLayer = true
        v.layer?.cornerRadius = 2
        v.layer?.masksToBounds = true
        
        return v
    }()
    
    private lazy var labIndicator: WWDCImageView = {
        let v = WWDCImageView()
        
        v.heightAnchor.constraint(equalToConstant: 48).isActive = true
        v.widthAnchor.constraint(equalToConstant: 85).isActive = true
        v.isHidden = true
        v.image = #imageLiteral(resourceName: "lab-indicator")
        
        return v
    }()
    
    private lazy var contextColorView: TrackColorView = {
        let v = TrackColorView()
        
        v.widthAnchor.constraint(equalToConstant: 4).isActive = true
        
        return v
    }()
    
    private lazy var textStackView: NSStackView = {
        let v = NSStackView(views: [self.titleLabel, self.subtitleLabel, self.contextLabel])
        
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        
        return v
    }()
    
    private lazy var mainStackView: NSStackView = {
        let v = NSStackView(views: [self.contextColorView, self.labIndicator, self.thumbnailImageView, self.textStackView])
        
        v.orientation = .horizontal
        v.translatesAutoresizingMaskIntoConstraints = false
        
        return v
    }()
    
    private func buildUI() {
        wantsLayer = true
        
        addSubview(mainStackView)
        mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10).isActive = true
        mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10).isActive = true
        mainStackView.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
        mainStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8).isActive = true
    }
    
}
