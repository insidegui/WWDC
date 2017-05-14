//
//  WWDCImageView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCImageView: NSView {

    var backgroundColor: NSColor = .clear {
        didSet {
            backgroundLayer.backgroundColor = backgroundColor.cgColor
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
    
}
