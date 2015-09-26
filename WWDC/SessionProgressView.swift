//
//  SessionStatusView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import QuartzCore

class SessionProgressView: NSView {

    var favorite: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    var progress: Double = 0 {
        didSet {
            updateUI()
        }
    }
    
    var selected = false {
        didSet {
            updateColors()
        }
    }
    
    private func updateUI() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.0)
        
        if favorite {
            bgShapeLayer.path = starPath
            
            if progress >= 1 {
                shapeLayer.path = nil
            } else {
                shapeLayer.path = starPath
            }
        } else {
            if progress >= 1 {
                bgShapeLayer.path = nil
                shapeLayer.path = nil
            } else if progress == 0 {
                bgShapeLayer.path = circlePath
                shapeLayer.path = circlePath
            } else if progress > 0 {
                bgShapeLayer.path = circlePath
                shapeLayer.path = halfCirclePath
            }
        }
        
        CATransaction.commit()
    }

    private var bgShapeLayer: CAShapeLayer!
    private var shapeLayer: CAShapeLayer!
    private var circlePath: CGMutablePathRef!
    private var halfCirclePath: CGMutablePathRef!
    private var starPath: CGMutablePathRef!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private var strokeColor: NSColor {
        get {
            return selected ? Theme.WWDCTheme.fillColor.darkerColor : Theme.WWDCTheme.fillColor
        }
    }
    
    private var fillColor: NSColor {
        get {
            return selected ? Theme.WWDCTheme.backgroundColor.colorWithAlphaComponent(0.9) : Theme.WWDCTheme.fillColor
        }
    }
    
    private var bgColor: NSColor {
        get {
            return selected ? Theme.WWDCTheme.fillColor : Theme.WWDCTheme.backgroundColor.colorWithAlphaComponent(0.9)
        }
    }
    
    private func commonInit() {
        wantsLayer = true
        layer = CALayer()
        
        shapeLayer = CAShapeLayer()
        shapeLayer.frame = CGRectInset(bounds, 4.0, 4.0)
        shapeLayer.autoresizingMask = [.LayerWidthSizable, .LayerHeightSizable]

        bgShapeLayer = CAShapeLayer()
        bgShapeLayer.frame = shapeLayer.frame
        bgShapeLayer.autoresizingMask = [.LayerWidthSizable, .LayerHeightSizable]
        bgShapeLayer.lineWidth = 1.0
        
        updateColors()
        
        preparePaths()

        bgShapeLayer.path = circlePath
        shapeLayer.path = circlePath
        layer?.addSublayer(bgShapeLayer)
        layer?.addSublayer(shapeLayer)
    }
    
    private func updateColors() {
        guard bgShapeLayer != nil || shapeLayer != nil else { return }
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.0)
        bgShapeLayer.strokeColor = strokeColor.CGColor
        shapeLayer.fillColor = fillColor.CGColor
        bgShapeLayer.fillColor = bgColor.CGColor
        CATransaction.commit()
    }
    
    private func preparePaths() {
        let shapeRect = CGRectInset(shapeLayer.bounds, 1.0, 1.0)
        
        circlePath = CGPathCreateMutable()
        CGPathAddEllipseInRect(circlePath, nil, shapeRect)
        
        halfCirclePath = CGPathCreateMutable()
        CGPathAddArc(halfCirclePath, nil, CGRectGetMidX(shapeRect), CGRectGetMidY(shapeRect), CGRectGetWidth(shapeRect)/2.0, -90.degreesToRadians, -270.degreesToRadians, true)
        
        starPath = CGPathCreateMutable()
        let a = (2 * M_PI) / 10
        let starRadius = Int(shapeLayer.bounds.size.width/2)
        let span = Double(shapeLayer.bounds.size.width/2)
        for i in 0...10 {
            let r = Double(starRadius * (i % 2 + 1) / 2)
            let o = a * Double(i)
            let x = CGFloat(r * sin(o) + span)
            let y = CGFloat(r * cos(o) + span)
            
            if (i == 0) {
                CGPathMoveToPoint(starPath, nil, x, y)
            } else {
                CGPathAddLineToPoint(starPath, nil, x, y)
            }
        }
        CGPathCloseSubpath(starPath)
    }
    
    override var flipped: Bool {
        get {
            return true
        }
    }
    
}

extension Int {
    var degreesToRadians : CGFloat {
        return CGFloat(self) * CGFloat(M_PI) / 180.0
    }
}