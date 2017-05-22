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
    
    fileprivate func updateUI() {
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

    fileprivate var bgShapeLayer: CAShapeLayer!
    fileprivate var shapeLayer: CAShapeLayer!
    fileprivate var circlePath: CGMutablePath!
    fileprivate var halfCirclePath: CGMutablePath!
    fileprivate var starPath: CGMutablePath!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    fileprivate var strokeColor: NSColor {
        get {
            return selected ? Theme.WWDCTheme.fillColor.darker : Theme.WWDCTheme.fillColor
        }
    }
    
    fileprivate var fillColor: NSColor {
        get {
            return selected ? Theme.WWDCTheme.backgroundColor.withAlphaComponent(0.9) : Theme.WWDCTheme.fillColor
        }
    }
    
    fileprivate var bgColor: NSColor {
        get {
            return selected ? Theme.WWDCTheme.fillColor : Theme.WWDCTheme.backgroundColor.withAlphaComponent(0.9)
        }
    }
    
    fileprivate func commonInit() {
        wantsLayer = true
        layer = CALayer()
        
        shapeLayer = CAShapeLayer()
        shapeLayer.frame = bounds.insetBy(dx: 4.0, dy: 4.0)
        shapeLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        bgShapeLayer = CAShapeLayer()
        bgShapeLayer.frame = shapeLayer.frame
        bgShapeLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        bgShapeLayer.lineWidth = 1.0
        
        updateColors()
        
        preparePaths()

        bgShapeLayer.path = circlePath
        shapeLayer.path = circlePath
        layer?.addSublayer(bgShapeLayer)
        layer?.addSublayer(shapeLayer)
    }
    
    fileprivate func updateColors() {
        guard bgShapeLayer != nil || shapeLayer != nil else { return }
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.0)
        bgShapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.fillColor = fillColor.cgColor
        bgShapeLayer.fillColor = bgColor.cgColor
        CATransaction.commit()
    }
    
    fileprivate func preparePaths() {
        let shapeRect = shapeLayer.bounds.insetBy(dx: 1.0, dy: 1.0)
        
        circlePath = CGMutablePath()
        circlePath.addEllipse(in: shapeRect)
        
        halfCirclePath = CGMutablePath()
        halfCirclePath.addArc(center: CGPoint(x: shapeRect.midX, y: shapeRect.midY), radius: shapeRect.width / 2.0, startAngle: -90.degreesToRadians, endAngle: -270.degreesToRadians, clockwise: true, transform: .identity)
        
        starPath = CGMutablePath()
        let a = (2 * Double.pi) / 10
        let starRadius = Int(shapeLayer.bounds.size.width/2)
        let span = Double(shapeLayer.bounds.size.width/2)
        for i in 0...10 {
            let r = Double(starRadius * (i % 2 + 1) / 2)
            let o = a * Double(i)
            let x = CGFloat(r * sin(o) + span)
            let y = CGFloat(r * cos(o) + span)
            
            if (i == 0) {
                starPath.move(to: CGPoint(x: x, y: y))
            } else {
                starPath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        starPath.closeSubpath()
    }
    
    override var isFlipped: Bool {
        get {
            return true
        }
    }
    
}

extension Int {
    var degreesToRadians : CGFloat {
        return CGFloat(self) * CGFloat(Double.pi) / 180.0
    }
}
