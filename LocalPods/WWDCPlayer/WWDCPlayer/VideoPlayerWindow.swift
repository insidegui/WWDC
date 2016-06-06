//
//  VideoPlayerWindow.swift
//  WWDCPlayer
//
//  Created by Guilherme Rambo on 02/04/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

public class VideoPlayerWindow: NSWindow {
    
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
    
    override init(contentRect: NSRect, styleMask aStyle: Int, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: aStyle, backing: bufferingType, defer: flag)
        
        applyCustomizations()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
        applyCustomizations()
    }
    
    public override var effectiveAppearance: NSAppearance {
        return NSAppearance(named: NSAppearanceNameVibrantDark)!
    }
    
    private var _storedTitlebarView: NSVisualEffectView?
    private var titlebarView: NSVisualEffectView? {
        guard _storedTitlebarView == nil else { return _storedTitlebarView }
        guard let containerClass = NSClassFromString("NSTitlebarContainerView") else { return nil }
        
        guard let containerView = contentView?.superview?.subviews.filter({ $0.isKindOfClass(containerClass) }).last else { return nil }
        
        guard let titlebar = containerView.subviews.filter({ $0.isKindOfClass(NSVisualEffectView.self) }).last as? NSVisualEffectView else { return nil }
        
        _storedTitlebarView = titlebar
        
        return _storedTitlebarView
    }
    private var titlebarWidgets: [NSButton]? {
        return titlebarView?.subviews.map({ $0 as? NSButton }).filter({ $0 != nil }).map({ $0! })
    }
    
    private var titleTextField: NSTextField?
    private var titlebarSeparatorLayer: CALayer?
    private var titlebarGradientLayer: CAGradientLayer?
    
    private var fullscreenObserver: NSObjectProtocol?
    
    @objc private func applyCustomizations(note: NSNotification? = nil) {
        titleVisibility = .Hidden
        movableByWindowBackground = true
        
        if #available(OSX 10.11, *) {
            titlebarView?.material = .UltraDark
        } else {
            titlebarView?.material = .Dark
        }
        
        titlebarView?.state = .Active
        
        installTitlebarGradientIfNeeded()
        installTitlebarSeparatorIfNeeded()
        installTitleTextFieldIfNeeded()
        
        installFullscreenObserverIfNeeded()
        
        applyAppearanceToWidgets()
    }
    
    private func appearanceForWidgets() -> NSAppearance? {
        return NSAppearance(named: NSAppearanceNameVibrantDark)
    }
    
    private func applyAppearanceToWidgets() {
        titlebarWidgets?.forEach { $0.appearance = appearanceForWidgets() }
    }
    
    private func installTitleTextFieldIfNeeded() {
        guard titleTextField == nil && titlebarView != nil else { return }
        
        titleTextField = NSTextField(frame: titlebarView!.bounds)
        titleTextField!.editable = false
        titleTextField!.selectable = false
        titleTextField!.drawsBackground = false
        titleTextField!.bezeled = false
        titleTextField!.bordered = false
        titleTextField!.stringValue = title
        titleTextField!.font = NSFont.titleBarFontOfSize(13.0)
        titleTextField!.textColor = NSColor(calibratedWhite: 0.9, alpha: 0.8)
        titleTextField!.alignment = .Center
        titleTextField!.translatesAutoresizingMaskIntoConstraints = false
        titleTextField!.lineBreakMode = .ByTruncatingMiddle
        titleTextField!.sizeToFit()
        
        titlebarView!.addSubview(titleTextField!)
        
        
        titlebarView?.addConstraints([
            NSLayoutConstraint(item: titleTextField!, attribute: .CenterX, relatedBy: .Equal, toItem: titlebarView!, attribute: .CenterX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: titleTextField!, attribute: .CenterY, relatedBy: .Equal, toItem: titlebarView!, attribute: .CenterY, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: titleTextField!, attribute: .Leading, relatedBy: .GreaterThanOrEqual, toItem: titlebarView!, attribute: .Leading, multiplier: 1.0, constant: 67.0)
        ])
        
        titleTextField!.setContentCompressionResistancePriority(0.1, forOrientation: .Horizontal)
        
        titleTextField!.layer?.compositingFilter = "lightenBlendMode"
    }
    
    private func installTitlebarGradientIfNeeded() {
        guard titlebarGradientLayer == nil && titlebarView != nil else { return }
        
        titlebarGradientLayer = CAGradientLayer()
        titlebarGradientLayer!.colors = [NSColor(calibratedWhite: 0.0, alpha: 0.4).CGColor, NSColor.clearColor().CGColor]
        titlebarGradientLayer!.frame = titlebarView!.bounds
        titlebarGradientLayer!.autoresizingMask = [.LayerWidthSizable, .LayerHeightSizable]
        titlebarGradientLayer!.compositingFilter = "overlayBlendMode"
        titlebarView?.layer?.insertSublayer(titlebarGradientLayer!, atIndex: 0)
    }
    
    private func installTitlebarSeparatorIfNeeded() {
        guard titlebarSeparatorLayer == nil && titlebarView != nil else { return }
        
        titlebarSeparatorLayer = CALayer()
        titlebarSeparatorLayer!.backgroundColor = NSColor.labelColor().colorWithAlphaComponent(0.7).CGColor
        titlebarSeparatorLayer!.frame = CGRect(x: 0.0, y: 0.0, width: titlebarView!.bounds.width, height: 1.0)
        titlebarSeparatorLayer!.autoresizingMask = [.LayerWidthSizable, .LayerMinYMargin]
        titlebarView?.layer?.addSublayer(titlebarSeparatorLayer!)
    }
    
    private func installFullscreenObserverIfNeeded() {
        guard fullscreenObserver == nil else { return }
        
        let nc = NSNotificationCenter.defaultCenter()
        
        // the customizations (especially the title text field ones) have to be reapplied when entering and exiting fullscreen
        nc.addObserver(self, selector: #selector(applyCustomizations), name: NSWindowDidEnterFullScreenNotification, object: self)
        nc.addObserver(self, selector: #selector(applyCustomizations), name: NSWindowDidExitFullScreenNotification, object: self)
    }
    
    public override func makeKeyAndOrderFront(sender: AnyObject?) {
        super.makeKeyAndOrderFront(sender)
        
        applyCustomizations()
    }
    
    public override var title: String {
        didSet {
            titleTextField?.stringValue = title
        }
    }
    
    private var actualContentView: NSView?
    private var darkContentView: DarkWindowContentView!
    
    public override var contentView: NSView? {
        set {
            actualContentView = newValue
            
            if darkContentView == nil {
                darkContentView = DarkWindowContentView(frame: newValue?.frame ?? NSZeroRect)
                darkContentView.wantsLayer = true
            }
            
            if let newContentView = actualContentView {
                newContentView.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
                darkContentView.addSubview(newContentView)
            }
            
            super.contentView = darkContentView
        }
        get {
            return super.contentView
        }
    }
    
    func hideTitlebar(animated: Bool = true) {
        NSNotificationCenter.defaultCenter().postNotificationName(Notifications.TitlebarWillDisappear, object: self)
        
        guard let titlebarView = titlebarView else { return }
        guard titlebarView.alphaValue > 0.0 else { return }
        
        setTitlebarOpacity(0.0, animated: animated)
    }
    
    func showTitlebar(animated: Bool = true) {
        NSNotificationCenter.defaultCenter().postNotificationName(Notifications.TitlebarWillAppear, object: self)
        
        guard let titlebarView = titlebarView else { return }
        guard titlebarView.alphaValue < 1.0 else { return }
        
        setTitlebarOpacity(1.0, animated: animated)
    }
    
    private func setTitlebarOpacity(opacity: CGFloat, animated: Bool) {
        guard hidesTitlebar else { return }
        
        // when the window is in full screen, the titlebar view is in another window (the "toolbar window")
        guard titlebarView?.window == self else { return }
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = animated ? 0.4 : 0.0
            self.titlebarView?.animator().alphaValue = opacity
            }, completionHandler: nil)
    }
    
    public override var backgroundColor: NSColor! {
        didSet {
            (contentView as? DarkWindowContentView)?.backgroundColor = backgroundColor
        }
    }
    
}

private class DarkWindowContentView: NSView {
    
    var backgroundColor: NSColor = NSColor(calibratedWhite: 0.1, alpha: 1.0) {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    private var overlayView: PlayerWindowOverlayView?
    
    private func installOverlayView() {
        guard overlayView == nil else { return }
        
        overlayView = PlayerWindowOverlayView(frame: bounds)
        overlayView!.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
        addSubview(overlayView!, positioned: .Above, relativeTo: subviews.last)
    }
    
    private func moveOverlayViewToTop() {
        if overlayView == nil {
            installOverlayView()
        } else {
            overlayView!.removeFromSuperview()
            addSubview(overlayView!, positioned: .Above, relativeTo: subviews.last)
        }
    }
    
    private override func drawRect(dirtyRect: NSRect) {
        backgroundColor.setFill()
        NSRectFill(dirtyRect)
    }
    
    private override func addSubview(aView: NSView) {
        super.addSubview(aView)
        
        if aView != overlayView {
            moveOverlayViewToTop()
        }
    }
    
}

private class PlayerWindowOverlayView: NSView {
    
    private var playerWindow: VideoPlayerWindow? {
        return window as? VideoPlayerWindow
    }
    
    private var mouseTrackingArea: NSTrackingArea!
    
    private override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if mouseTrackingArea != nil {
            removeTrackingArea(mouseTrackingArea)
        }
        
        mouseTrackingArea = NSTrackingArea(rect: bounds, options: [.InVisibleRect, .MouseEnteredAndExited, .MouseMoved, .ActiveAlways], owner: self, userInfo: nil)
        addTrackingArea(mouseTrackingArea)
    }
    
    private var mouseIdleTimer: NSTimer!
    
    private func resetMouseIdleTimer() {
        if mouseIdleTimer != nil {
            mouseIdleTimer.invalidate()
            mouseIdleTimer = nil
        }
        
        mouseIdleTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: #selector(mouseIdleTimerAction(_:)), userInfo: nil, repeats: false)
    }
    
    @objc private func mouseIdleTimerAction(sender: NSTimer) {
        playerWindow?.hideTitlebar()
    }
    
    private override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(windowWillExitFullscreen), name: NSWindowWillExitFullScreenNotification, object: window)
        resetMouseIdleTimer()
    }
    
    @objc private func windowWillExitFullscreen() {
        resetMouseIdleTimer()
    }
    
    private override func mouseEntered(theEvent: NSEvent) {
        resetMouseIdleTimer()
        playerWindow?.showTitlebar()
    }
    
    private override func mouseExited(theEvent: NSEvent) {
        playerWindow?.hideTitlebar()
    }
    
    private override func mouseMoved(theEvent: NSEvent) {
        resetMouseIdleTimer()
        playerWindow?.showTitlebar()
    }
    
    private override func mouseDown(theEvent: NSEvent) {
        if theEvent.clickCount == 2 {
            window?.toggleFullScreen(self)
        } else {
            if #available(OSX 10.11, *) {
                window?.performWindowDragWithEvent(theEvent)
            }
        }
        
        super.mouseDown(theEvent)
    }
    
    private override func drawRect(dirtyRect: NSRect) {
        return
    }
    
    private override func acceptsFirstMouse(theEvent: NSEvent?) -> Bool {
        guard let event = theEvent else { return false }
        guard event.type == .LeftMouseDown else { return false }
        
        return true
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        mouseIdleTimer.invalidate()
        mouseIdleTimer = nil
    }
    
}