//
//  PUIButton.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 29/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

public final class PUIButton: NSControl {

    public var isToggle = false

    public var activeTintColor: NSColor = .playerHighlight {
        didSet {
            setNeedsDisplay()
        }
    }

    public var tintColor: NSColor = .buttonColor {
        didSet {
            setNeedsDisplay()
        }
    }

    public var state: Int = NSOffState {
        didSet {
            setNeedsDisplay()
        }
    }

    public var showsMenuOnLeftClick = false
    public var sendsActionOnMouseDown = false

    public var image: NSImage? {
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

    public var alternateImage: NSImage? {
        didSet {
            guard let alternateImage = alternateImage else { return }

            if alternateImage.isTemplate {
                self.alternateMaskImage = alternateImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            } else {
                self.alternateMaskImage = nil
            }

            invalidateIntrinsicContentSize()
        }
    }

    private var maskImage: CGImage? {
        didSet {
            setNeedsDisplay()
        }
    }

    private var alternateMaskImage: CGImage? {
        didSet {
            setNeedsDisplay()
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        if let maskImage = maskImage {
            if let alternateMaskImage = alternateMaskImage, state == NSOnState {
                drawMask(alternateMaskImage)
            } else {
                drawMask(maskImage)
            }
        } else {
            if let alternateImage = alternateImage, state == NSOnState {
                drawImage(alternateImage)
            } else {
                drawImage(image)
            }
        }
    }

    private func drawMask(_ maskImage: CGImage) {
        guard let ctx = NSGraphicsContext.current()?.cgContext else { return }

        ctx.clip(to: bounds, mask: maskImage)

        if shouldDrawHighlighted || state == NSOnState || shouldAlwaysDrawHighlighted {
            ctx.setFillColor(activeTintColor.cgColor)
        } else if !isEnabled {
            let color = shouldAlwaysDrawHighlighted ? activeTintColor : tintColor
            ctx.setFillColor(color.withAlphaComponent(0.5).cgColor)
        } else {
            ctx.setFillColor(tintColor.cgColor)
        }

        ctx.fill(bounds)
    }

    private func drawImage(_ image: NSImage?) {
        image?.draw(in: bounds)
    }

    public override var intrinsicContentSize: NSSize {
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

    public var shouldAlwaysDrawHighlighted: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }

    public override var isEnabled: Bool {
        didSet {
            setNeedsDisplay()
        }
    }

    public override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        guard !showsMenuOnLeftClick else {
            showMenu(with: event)
            return
        }

        shouldDrawHighlighted = true

        if !sendsActionOnMouseDown {
            window?.trackEvents(matching: [.leftMouseUp, .leftMouseDragged], timeout: NSEventDurationForever, mode: .eventTrackingRunLoopMode) { e, stop in
                if e.type == .leftMouseUp {
                    self.shouldDrawHighlighted = false
                    stop.pointee = true
                }
            }
        }

        if let action = action, let target = target {
            if isToggle {
                self.state = (self.state == NSOnState) ? NSOffState : NSOnState
            }
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    private func showMenu(with event: NSEvent) {
        guard let menu = self.menu else { return }

        menu.popUp(positioning: nil, at: .zero, in: self)
    }

    public override var effectiveAppearance: NSAppearance {
        return NSAppearance(named: NSAppearanceNameVibrantDark)!
    }
    
    public override var allowsVibrancy: Bool {
        return true
    }
    
}
