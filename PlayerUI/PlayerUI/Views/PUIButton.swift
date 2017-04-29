//
//  PUIButton.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PUIButton: NSControl {
    
    var image: NSImage? {
        didSet {
            guard let image = image else { return }
            
            if image.isTemplate {
                self.maskImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            } else {
                self.maskImage = nil
            }
            
            invalidateIntrinsicContentSize()
        }
    }
    
    private var maskImage: CGImage? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        if let maskImage = maskImage {
            drawMask(maskImage)
        } else {
            drawImage()
        }
    }
    
    private func drawMask(_ maskImage: CGImage) {
        guard let ctx = NSGraphicsContext.current()?.cgContext else { return }
        
        ctx.clip(to: bounds, mask: maskImage)
        
        if shouldDrawHighlighted {
            ctx.setFillColor(NSColor.playerHighlight.cgColor)
        } else if !isEnabled {
            ctx.setFillColor(NSColor.buttonColor.withAlphaComponent(0.5).cgColor)
        } else {
            ctx.setFillColor(NSColor.buttonColor.cgColor)
        }
        
        ctx.fill(bounds)
    }
    
    private func drawImage() {
        guard let image = image else { return }
        
        image.draw(in: bounds)
    }
    
    override var intrinsicContentSize: NSSize {
        if let image = image {
            return image.size
        } else {
            return NSSize(width: -1, height: -1)
        }
    }
    
    private var shouldDrawHighlighted: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        
        shouldDrawHighlighted = true
        
        window?.trackEvents(matching: [.leftMouseUp, .leftMouseDragged], timeout: NSEventDurationForever, mode: .eventTrackingRunLoopMode) { e, stop in
            if e.type == .leftMouseUp {
                self.shouldDrawHighlighted = false
                stop.pointee = true
            }
        }
        
        if let action = action, let target = target {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
    
    override var allowsVibrancy: Bool {
        return true
    }
    
}
