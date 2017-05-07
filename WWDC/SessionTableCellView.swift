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
            guard let viewModel = viewModel else { return }
            
            viewModel.rxModelChange.asObservable().subscribe(onNext: { [weak self] _ in
                self?.updateUI()
            }).addDisposableTo(self.disposeBag)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        buildUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.disposeBag = DisposeBag()
        
        thumbnailImageView.image = #imageLiteral(resourceName: "noimage")
    }
    
    private func updateUI() {
        guard let viewModel = viewModel else { return }
        
        titleLabel.stringValue = viewModel.title
        subtitleLabel.stringValue = viewModel.subtitle
        contextLabel.stringValue = viewModel.context
        
        thumbnailImageView.image = #imageLiteral(resourceName: "noimage")
        
        if let imageUrl = viewModel.imageUrl {
            ImageCache.shared.fetchImage(at: imageUrl) { [weak self] url, image in
                guard url == imageUrl else { return }
                
                self?.thumbnailImageView.image = image
            }
        }
        
        contextColorView.layer?.backgroundColor = viewModel.color.cgColor
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
    
    private lazy var contextColorView: NSView = {
        let v = NSView()
        
        v.layer = CALayer()
        v.layer?.backgroundColor = NSColor.red.cgColor
        v.layer?.cornerRadius = 2
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
        let v = NSStackView(views: [self.contextColorView, self.thumbnailImageView, self.textStackView])
        
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
