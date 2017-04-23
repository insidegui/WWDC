//
//  VideoPlayerWindow.swift
//  WWDCPlayer
//
//  Created by Guilherme Rambo on 02/04/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

open class VideoPlayerWindow: NSWindow {
    
    deinit {
        #if DEBUG
        Swift.print("VideoPlayerWindow is gone")
        #endif
    }
    
    struct Notifications {
        static let TitlebarWillAppear = "DarkWindowTitlebarWillAppearNotification"
        static let TitlebarWillDisappear = "DarkWindowTitlebarWillDisappearNotification"
    }
    
    @IBInspectable var hidesTitlebar = true
    
    override init(contentRect: NSRect, styleMask aStyle: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: aStyle, backing: bufferingType, defer: flag)
        
        applyCustomizations()
    }
    
    open override var effectiveAppearance: NSAppearance {
        return NSAppearance(named: NSAppearanceNameVibrantDark)!
    }
    
    fileprivate var _storedTitlebarView: NSVisualEffectView?
    fileprivate var titlebarView: NSVisualEffectView? {
        guard _storedTitlebarView == nil else { return _storedTitlebarView }
        guard let containerClass = NSClassFromString("NSTitlebarContainerView") else { return nil }
        
        guard let containerView = contentView?.superview?.subviews.filter({ $0.isKind(of: containerClass) }).last else { return nil }
        
        guard let titlebar = containerView.subviews.filter({ $0.isKind(of: NSVisualEffectView.self) }).last as? NSVisualEffectView else { return nil }
        
        _storedTitlebarView = titlebar
        
        return _storedTitlebarView
    }
    fileprivate var titlebarWidgets: [NSButton]? {
        return titlebarView?.subviews.map({ $0 as? NSButton }).filter({ $0 != nil }).map({ $0! })
    }
    
    fileprivate var titleTextField: NSTextField?
    fileprivate var titlebarSeparatorLayer: CALayer?
    fileprivate var titlebarGradientLayer: CAGradientLayer?
    
    fileprivate var fullscreenObserver: NSObjectProtocol?
    
    @objc fileprivate func applyCustomizations(_ note: Notification? = nil) {
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        
        if #available(OSX 10.11, *) {
            titlebarView?.material = .ultraDark
        } else {
            titlebarView?.material = .dark
        }
        
        titlebarView?.state = .active
        
        installTitlebarGradientIfNeeded()
        installTitlebarSeparatorIfNeeded()
        installTitleTextFieldIfNeeded()
        
        installFullscreenObserverIfNeeded()
        
        applyAppearanceToWidgets()
    }
    
    fileprivate func appearanceForWidgets() -> NSAppearance? {
        return NSAppearance(named: NSAppearanceNameVibrantDark)
    }
    
    fileprivate func applyAppearanceToWidgets() {
        titlebarWidgets?.forEach { $0.appearance = appearanceForWidgets() }
    }
    
    fileprivate func installTitleTextFieldIfNeeded() {
        guard titleTextField == nil && titlebarView != nil else { return }
        
        titleTextField = NSTextField(frame: titlebarView!.bounds)
        titleTextField!.isEditable = false
        titleTextField!.isSelectable = false
        titleTextField!.drawsBackground = false
        titleTextField!.isBezeled = false
        titleTextField!.isBordered = false
        titleTextField!.stringValue = title
        titleTextField!.font = NSFont.titleBarFont(ofSize: 13.0)
        titleTextField!.textColor = NSColor(calibratedWhite: 0.9, alpha: 0.8)
        titleTextField!.alignment = .center
        titleTextField!.translatesAutoresizingMaskIntoConstraints = false
        titleTextField!.lineBreakMode = .byTruncatingMiddle
        titleTextField!.sizeToFit()
        
        titlebarView!.addSubview(titleTextField!)
        
        
        titlebarView?.addConstraints([
            NSLayoutConstraint(item: titleTextField!, attribute: .centerX, relatedBy: .equal, toItem: titlebarView!, attribute: .centerX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: titleTextField!, attribute: .centerY, relatedBy: .equal, toItem: titlebarView!, attribute: .centerY, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: titleTextField!, attribute: .leading, relatedBy: .greaterThanOrEqual, toItem: titlebarView!, attribute: .leading, multiplier: 1.0, constant: 67.0)
        ])
        
        titleTextField!.setContentCompressionResistancePriority(0.1, for: .horizontal)
        
        titleTextField!.layer?.compositingFilter = "lightenBlendMode"
    }
    
    fileprivate func installTitlebarGradientIfNeeded() {
        guard titlebarGradientLayer == nil && titlebarView != nil else { return }
        
        titlebarGradientLayer = CAGradientLayer()
        titlebarGradientLayer!.colors = [NSColor(calibratedWhite: 0.0, alpha: 0.4).cgColor, NSColor.clear.cgColor]
        titlebarGradientLayer!.frame = titlebarView!.bounds
        titlebarGradientLayer!.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        titlebarGradientLayer!.compositingFilter = "overlayBlendMode"
        titlebarView?.layer?.insertSublayer(titlebarGradientLayer!, at: 0)
    }
    
    fileprivate func installTitlebarSeparatorIfNeeded() {
        guard titlebarSeparatorLayer == nil && titlebarView != nil else { return }
        
        titlebarSeparatorLayer = CALayer()
        titlebarSeparatorLayer!.backgroundColor = NSColor.labelColor.withAlphaComponent(0.7).cgColor
        titlebarSeparatorLayer!.frame = CGRect(x: 0.0, y: 0.0, width: titlebarView!.bounds.width, height: 1.0)
        titlebarSeparatorLayer!.autoresizingMask = [.layerWidthSizable, .layerMinYMargin]
        titlebarView?.layer?.addSublayer(titlebarSeparatorLayer!)
    }
    
    fileprivate func installFullscreenObserverIfNeeded() {
        guard fullscreenObserver == nil else { return }
        
        let nc = NotificationCenter.default
        
        // the customizations (especially the title text field ones) have to be reapplied when entering and exiting fullscreen
        nc.addObserver(self, selector: #selector(applyCustomizations), name: NSNotification.Name.NSWindowDidEnterFullScreen, object: self)
        nc.addObserver(self, selector: #selector(applyCustomizations), name: NSNotification.Name.NSWindowDidExitFullScreen, object: self)
    }
    
    open override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        
        applyCustomizations()
    }
    
    open override var title: String {
        didSet {
            titleTextField?.stringValue = title
        }
    }
    
    fileprivate var actualContentView: NSView?
    fileprivate var darkContentView: DarkWindowContentView!
    
    open override var contentView: NSView? {
        set {
            actualContentView = newValue
            
            if darkContentView == nil {
                darkContentView = DarkWindowContentView(frame: newValue?.frame ?? NSZeroRect)
                darkContentView.wantsLayer = true
            }
            
            if let newContentView = actualContentView {
                newContentView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
                darkContentView.addSubview(newContentView)
            }
            
            super.contentView = darkContentView
        }
        get {
            return super.contentView
        }
    }
    
    func hideTitlebar(_ animated: Bool = true) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.TitlebarWillDisappear), object: self)
        
        guard let titlebarView = titlebarView else { return }
        guard titlebarView.alphaValue > 0.0 else { return }
        
        setTitlebarOpacity(0.0, animated: animated)
    }
    
    func showTitlebar(_ animated: Bool = true) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.TitlebarWillAppear), object: self)
        
        guard let titlebarView = titlebarView else { return }
        guard titlebarView.alphaValue < 1.0 else { return }
        
        setTitlebarOpacity(1.0, animated: animated)
    }
    
    fileprivate func setTitlebarOpacity(_ opacity: CGFloat, animated: Bool) {
        guard hidesTitlebar else { return }
        
        // when the window is in full screen, the titlebar view is in another window (the "toolbar window")
        guard titlebarView?.window == self else { return }
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = animated ? 0.4 : 0.0
            self.titlebarView?.animator().alphaValue = opacity
            }, completionHandler: nil)
    }
    
    open override var backgroundColor: NSColor! {
        didSet {
            (contentView as? DarkWindowContentView)?.backgroundColor = backgroundColor
        }
    }
    
}

private class DarkWindowContentView: NSView {
    
    var backgroundColor: NSColor = NSColor(calibratedWhite: 0.1, alpha: 1.0) {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    fileprivate var overlayView: PlayerWindowOverlayView?
    
    fileprivate func installOverlayView() {
        guard overlayView == nil else { return }
        
        overlayView = PlayerWindowOverlayView(frame: bounds)
        overlayView!.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        addSubview(overlayView!, positioned: .above, relativeTo: subviews.last)
    }
    
    fileprivate func moveOverlayViewToTop() {
        if overlayView == nil {
            installOverlayView()
        } else {
            overlayView!.removeFromSuperview()
            addSubview(overlayView!, positioned: .above, relativeTo: subviews.last)
        }
    }
    
    fileprivate override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        NSRectFill(dirtyRect)
    }
    
    fileprivate override func addSubview(_ aView: NSView) {
        super.addSubview(aView)
        
        if aView != overlayView {
            moveOverlayViewToTop()
        }
    }
    
}

private class PlayerWindowOverlayView: NSView {
    
    fileprivate var playerWindow: VideoPlayerWindow? {
        return window as? VideoPlayerWindow
    }
    
    fileprivate var mouseTrackingArea: NSTrackingArea!
    
    fileprivate override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if mouseTrackingArea != nil {
            removeTrackingArea(mouseTrackingArea)
        }
        
        mouseTrackingArea = NSTrackingArea(rect: bounds, options: [.inVisibleRect, .mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(mouseTrackingArea)
    }
    
    fileprivate var mouseIdleTimer: Timer!
    
    fileprivate func resetMouseIdleTimer() {
        if mouseIdleTimer != nil {
            mouseIdleTimer.invalidate()
            mouseIdleTimer = nil
        }
        
        mouseIdleTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(mouseIdleTimerAction(_:)), userInfo: nil, repeats: false)
    }
    
    @objc fileprivate func mouseIdleTimerAction(_ sender: Timer) {
        playerWindow?.hideTitlebar()
    }
    
    fileprivate override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillExitFullscreen), name: NSNotification.Name.NSWindowWillExitFullScreen, object: window)
        resetMouseIdleTimer()
    }
    
    @objc fileprivate func windowWillExitFullscreen() {
        resetMouseIdleTimer()
    }
    
    fileprivate override func mouseEntered(with theEvent: NSEvent) {
        resetMouseIdleTimer()
        playerWindow?.showTitlebar()
    }
    
    fileprivate override func mouseExited(with theEvent: NSEvent) {
        playerWindow?.hideTitlebar()
    }
    
    fileprivate override func mouseMoved(with theEvent: NSEvent) {
        resetMouseIdleTimer()
        playerWindow?.showTitlebar()
    }
    
    fileprivate override func mouseDown(with theEvent: NSEvent) {
        if theEvent.clickCount == 2 {
            window?.toggleFullScreen(self)
        } else {
            if #available(OSX 10.11, *) {
                window?.performDrag(with: theEvent)
            }
        }
        
        super.mouseDown(with: theEvent)
    }
    
    fileprivate override func draw(_ dirtyRect: NSRect) {
        return
    }
    
    fileprivate override func acceptsFirstMouse(for theEvent: NSEvent?) -> Bool {
        guard let event = theEvent else { return false }
        guard event.type == .leftMouseDown else { return false }
        
        return true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        mouseIdleTimer.invalidate()
        mouseIdleTimer = nil
    }
    
}
