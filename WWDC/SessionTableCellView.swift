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
            
            self.disposeBag = DisposeBag()
            
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
        
        downloadedImageView.isHidden = true
        favoritedImageView.isHidden = true
        
        thumbnailImageView.image = #imageLiteral(resourceName: "noimage")
    }
    
    private func bindUI() {
        self.disposeBag = DisposeBag()
        
        guard let viewModel = viewModel else { return }
        
        viewModel.rxTitle.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(titleLabel.rx.text).addDisposableTo(self.disposeBag)
        viewModel.rxSubtitle.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(subtitleLabel.rx.text).addDisposableTo(self.disposeBag)
        viewModel.rxContext.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(contextLabel.rx.text).addDisposableTo(self.disposeBag)
        
        viewModel.rxIsFavorite.distinctUntilChanged().map({ !$0 }).bind(to: favoritedImageView.rx.isHidden).addDisposableTo(self.disposeBag)
        viewModel.rxIsDownloaded.distinctUntilChanged().map({ !$0 }).bind(to: downloadedImageView.rx.isHidden).addDisposableTo(self.disposeBag)
        
        let isSnowFlake = Observable.zip(viewModel.rxIsCurrentlyLive, viewModel.rxIsLab)
        
        isSnowFlake.map({ !$0.0 && !$0.1 }).bind(to: self.snowFlakeView.rx.isHidden).addDisposableTo(self.disposeBag)
        isSnowFlake.map({ $0.0 || $0.1 }).bind(to: self.thumbnailImageView.rx.isHidden).addDisposableTo(self.disposeBag)
        
        isSnowFlake.subscribe(onNext: { [weak self] (isLive: Bool, isLab: Bool) -> Void in
            if isLive {
                self?.snowFlakeView.image = #imageLiteral(resourceName: "live-indicator")
            } else if isLab {
                self?.snowFlakeView.image = #imageLiteral(resourceName: "lab-indicator")
            }
        }).addDisposableTo(self.disposeBag)
        
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
            self?.snowFlakeView.backgroundColor = color
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
        
        viewModel.rxSessionType.distinctUntilChanged().subscribe(onNext: { [weak self] type in
            guard type != .session && type != .lab else { return }
            
            switch type {
            case .getTogether:
                self?.thumbnailImageView.image = #imageLiteral(resourceName: "get-together")
            default:
                self?.thumbnailImageView.image = #imageLiteral(resourceName: "special")
            }
        }).addDisposableTo(self.disposeBag)
    }
    
    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 14, weight: NSFontWeightMedium)
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
        l.textColor = .tertiaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        
        return l
    }()
    
    private lazy var thumbnailImageView: WWDCImageView = {
        let v = WWDCImageView()
        
        v.heightAnchor.constraint(equalToConstant: 48).isActive = true
        v.widthAnchor.constraint(equalToConstant: 85).isActive = true
        v.backgroundColor = .black
        
        return v
    }()
    
    private lazy var snowFlakeView: WWDCImageView = {
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
        v.distribution = .equalSpacing
        v.spacing = 0
        
        return v
    }()
    
    private lazy var favoritedImageView: WWDCImageView = {
        let v = WWDCImageView()
        
        v.heightAnchor.constraint(equalToConstant: 14).isActive = true
        v.drawsBackground = false
        v.image = #imageLiteral(resourceName: "star-small")
        
        return v
    }()
    
    private lazy var downloadedImageView: WWDCImageView = {
        let v = WWDCImageView()
        
        v.heightAnchor.constraint(equalToConstant: 11).isActive = true
        v.drawsBackground = false
        v.image = #imageLiteral(resourceName: "download-small")
        
        return v
    }()
    
    private lazy var iconsStackView: NSStackView = {
        let v = NSStackView(views: [])
        
        v.distribution = .gravityAreas
        v.orientation = .vertical
        v.spacing = 4
        v.addView(self.favoritedImageView, in: .top)
        v.addView(self.downloadedImageView, in: .bottom)
        v.translatesAutoresizingMaskIntoConstraints = false
        
        v.widthAnchor.constraint(equalToConstant: 12).isActive = true
        
        return v
    }()
    
    private func buildUI() {
        wantsLayer = true
        
        contextColorView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        snowFlakeView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        iconsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(contextColorView)
        addSubview(thumbnailImageView)
        addSubview(snowFlakeView)
        addSubview(textStackView)
        addSubview(iconsStackView)
        
        contextColorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10).isActive = true
        contextColorView.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
        contextColorView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8).isActive = true
        
        thumbnailImageView.centerYAnchor.constraint(equalTo: contextColorView.centerYAnchor).isActive = true
        thumbnailImageView.leadingAnchor.constraint(equalTo: contextColorView.trailingAnchor, constant: 8).isActive = true
        snowFlakeView.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor).isActive = true
        snowFlakeView.centerXAnchor.constraint(equalTo: thumbnailImageView.centerXAnchor).isActive = true
        
        textStackView.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor, constant: -1).isActive = true
        textStackView.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 8).isActive = true
        textStackView.trailingAnchor.constraint(equalTo: iconsStackView.leadingAnchor, constant: -2).isActive = true

        iconsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4).isActive = true
        iconsStackView.topAnchor.constraint(equalTo: textStackView.topAnchor).isActive = true
        iconsStackView.bottomAnchor.constraint(equalTo: textStackView.bottomAnchor).isActive = true
    }
    
}
