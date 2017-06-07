//
//  WWDCImageView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

protocol WWDCImageViewDelegate: class {
    
    func wwdcImageView(_ imageView: WWDCImageView, didReceiveNewImageWithFileURL url: URL)
    
}

class WWDCImageView: NSView {
    
    weak var delegate: WWDCImageViewDelegate?
    
    var isRounded = false {
        didSet {
            updateRoundness()
        }
    }
    
    var drawsBackground = true {
        didSet {
            self.backgroundLayer.isHidden = !drawsBackground
        }
    }
    
    override var isOpaque: Bool {
        return drawsBackground && !isRounded
    }
    
    var backgroundColor: NSColor = .clear {
        didSet {
            backgroundLayer.backgroundColor = backgroundColor.cgColor
        }
    }
    
    var isEditable: Bool = false {
        didSet {
            if isEditable {
                register(forDraggedTypes: [NSURLPboardType, NSFilenamesPboardType])
            } else {
                unregisterDraggedTypes()
            }
        }
    }
    
    var image: NSImage? = nil {
        didSet {
            imageLayer.contents = image
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        buildUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var backgroundLayer: WWDCLayer = {
        let l = WWDCLayer()
        
        l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        return l
    }()
    
    private lazy var imageLayer: WWDCLayer = {
        let l = WWDCLayer()
        
        l.contentsGravity = kCAGravityResizeAspect
        l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        l.zPosition = 1
        
        return l
    }()
    
    private func buildUI() {
        self.wantsLayer = true
        self.layer = WWDCLayer()
        self.layer?.cornerRadius = 2
        self.layer?.masksToBounds = true
        
        backgroundLayer.frame = bounds
        imageLayer.frame = bounds
        
        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(imageLayer)
    }
    
    override func layout() {
        super.layout()
        
        updateRoundness()
    }
    
    // MARK: - Editing
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let file = (sender.draggingPasteboard().propertyList(forType: NSFilenamesPboardType) as? [String])?.first else { return false }
        
        let fileURL = URL(fileURLWithPath: file)
        
        guard let image = NSImage.thumbnailImage(with: fileURL, maxWidth: 400) else {
            return false
        }
        
        self.image = image
        delegate?.wwdcImageView(self, didReceiveNewImageWithFileURL: fileURL)
        
        return true
    }
    
    private func updateRoundness() {
        guard let layer = layer else { return }
        
        layer.cornerRadius = isRounded ? layer.bounds.height / 2 : 0
    }
    
}
