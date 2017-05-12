//
//  TrackColorView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class TrackColorView: NSView, CALayerDelegate {
    
    private lazy var progressLayer: CALayer = {
        let l = CALayer()
        
        l.autoresizingMask = [.layerWidthSizable]
        
        return l
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        wantsLayer = true
        layer = CALayer()
        
        layer?.delegate = self
        progressLayer.delegate = self
        
        layer?.cornerRadius = 2
        layer?.masksToBounds = true
        
        progressLayer.frame = bounds
        
        layer?.addSublayer(progressLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var progress: Double = 0.5 {
        didSet {
            if progress < 1 {
                layer?.borderWidth = 1
            } else {
                layer?.borderWidth = 0
            }
            
            needsLayout = true
        }
    }
    
    var color: NSColor = .black {
        didSet {
            layer?.borderColor = color.cgColor
            progressLayer.backgroundColor = color.cgColor
        }
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: 4, height: -1)
    }
    
    override func layout() {
        super.layout()
        
        let progressFrame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height * CGFloat(progress))
        progressLayer.frame = progressFrame
    }
    
    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return nil
    }
    
}
