//
//  TabItemView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSStackView {
    
    var computedContentSize: CGSize {
        switch orientation {
        case .horizontal:
            let height = arrangedSubviews.map({ $0.bounds.height }).max() ?? CGFloat(0)
            let width = arrangedSubviews.reduce(CGFloat(0), { $0 + $1.intrinsicContentSize.width + self.spacing })
            
            return CGSize(width: width - spacing, height: height)
        case .vertical:
            let width = arrangedSubviews.map({ $0.bounds.width }).max() ?? CGFloat(0)
            let height = arrangedSubviews.reduce(CGFloat(0), { $0 + $1.intrinsicContentSize.height + self.spacing })
            
            return CGSize(width: width, height: height - spacing)
        }
    }
    
}

final class TabItemView: NSView {
    
    var target: Any?
    var action: Selector?
    
    var controllerIdentifier: String = ""
    
    var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
            titleLabel.sizeToFit()
            sizeToFit()
        }
    }
    
    var image: NSImage? {
        didSet {
            if state == NSOffState {
                imageView.image = image
                sizeToFit()
            }
        }
    }
    
    var alternateImage: NSImage? {
        didSet {
            if state == NSOnState {
                imageView.image = alternateImage
                sizeToFit()
            }
        }
    }
    
    var state: Int = NSOffState {
        didSet {
            if state == NSOnState {
                imageView.tintColor = .toolbarTintActive
                imageView.image = alternateImage
                titleLabel.textColor = .toolbarTintActive
                titleLabel.font = NSFont.systemFont(ofSize: 14, weight: NSFontWeightMedium)
            } else {
                imageView.tintColor = .toolbarTint
                imageView.image = image
                titleLabel.textColor = .toolbarTint
                titleLabel.font = NSFont.systemFont(ofSize: 14)
            }
        }
    }
    
    lazy var imageView: MaskImageView = {
        let v = MaskImageView()
        
        v.tintColor = .toolbarTint
        v.widthAnchor.constraint(equalToConstant: 20).isActive = true
        v.heightAnchor.constraint(equalToConstant: 15).isActive = true
        
        return v
    }()
    
    lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        
        l.font = NSFont.systemFont(ofSize: 14)
        l.textColor = .toolbarTint
        l.cell?.backgroundStyle = .dark
        
        return l
    }()
    
    lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.imageView, self.titleLabel])
        
        v.orientation = .horizontal
        v.spacing = 5
        v.alignment = .centerY
        v.distribution = .equalCentering
        
        return v
    }()
    
    override var intrinsicContentSize: NSSize {
        get {
            return stackView.computedContentSize
        }
        set {
            
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        wantsLayer = true
        
        addSubview(stackView)
        stackView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    func sizeToFit() {
        frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: intrinsicContentSize.width, height: intrinsicContentSize.height)
    }
    
    override func mouseDown(with event: NSEvent) {
        if let target = target, let action = action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
    
}
