//
//  WWDCWindow.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension Notification.Name {
    static let WWDCWindowWillShowUIMask = Notification.Name("WWDCWindowWillShowUIMask")
    static let WWDCWindowWillHideUIMask = Notification.Name("WWDCWindowWillHideUIMask")
}

final class WWDCWindow: NSWindow {

    // MARK: - Initialization

    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)

        applyCustomizations()
    }

    public override func awakeFromNib() {
        super.awakeFromNib()

        applyCustomizations()
    }

    // MARK: - Custom appearance

    fileprivate var _storedTitlebarView: NSVisualEffectView?
    public var titlebarView: NSVisualEffectView? {
        guard _storedTitlebarView == nil else { return _storedTitlebarView }
        guard let containerClass = NSClassFromString("NSTitlebarContainerView") else { return nil }

        guard let containerView = contentView?.superview?.subviews.reversed().first(where: { $0.isKind(of: containerClass) }) else { return nil }

        guard let titlebar = containerView.subviews.reversed().first(where: { $0.isKind(of: NSVisualEffectView.self) }) as? NSVisualEffectView else { return nil }

        _storedTitlebarView = titlebar

        return _storedTitlebarView
    }

    fileprivate func applyCustomizations(_ note: Notification? = nil) {
        backgroundColor = .darkWindowBackground

        titleVisibility = .hidden
        isMovableByWindowBackground = true
        tabbingMode = .disallowed

        titlebarView?.material = .ultraDark
        titlebarView?.state = .inactive
        titlebarView?.layer?.backgroundColor = NSColor.darkTitlebarBackground.cgColor
    }

    private var uiMaskView: WWDCUIMaskView?

    @objc func maskUI(preserving view: NSView) {
        guard let contentView = contentView else { return }
        guard let frame = view.superview?.convert(view.frame, to: nil) else { return }

        NotificationCenter.default.post(name: .WWDCWindowWillShowUIMask, object: self)

        let mask = WWDCUIMaskView(frame: contentView.bounds)
        mask.holeRect = frame
        mask.autoresizingMask = [.width, .height]
        mask.alphaValue = 0
        contentView.addSubview(mask)

        uiMaskView = mask

        mask.animator().alphaValue = 1

        styleMask.remove(.resizable)
    }

    @objc func hideUIMask() {
        NotificationCenter.default.post(name: .WWDCWindowWillHideUIMask, object: self)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.completionHandler = { [weak self] in
                self?.uiMaskView?.removeFromSuperview()
                self?.uiMaskView = nil
            }

            self.uiMaskView?.animator().alphaValue = 0
        }

        styleMask.insert(.resizable)
    }

}

fileprivate final class WWDCUIMaskView: NSView {

    var holeRect: CGRect = .zero {
        didSet {
            setNeedsDisplay(bounds)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.88).setFill()
        bounds.fill()

        NSColor.clear.setFill()
        holeRect.fill(using: .sourceOut)
    }

    override func mouseDown(with event: NSEvent) {
        let clickedPoint = convert(event.locationInWindow, from: nil)

        guard !holeRect.contains(clickedPoint) else {
            super.mouseDown(with: event)
            return
        }

        NSApp.sendAction(#selector(WWDCWindow.hideUIMask), to: nil, from: nil)
    }

}
