//
//  PUIPlayerWindow.swift
//  BonatesPlayer (originally from EventsUI)
//
//  Created by Guilherme Rambo on 02/04/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation

open class PUIPlayerWindow: NSWindow {

    @IBInspectable @objc open var hidesTitlebar = true

    // MARK: - Initialization

    public override init(contentRect: NSRect, styleMask style: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        var effectiveStyle = style
        effectiveStyle.insert(.fullSizeContentView)

        super.init(contentRect: contentRect, styleMask: effectiveStyle, backing: bufferingType, defer: flag)

        applyCustomizations()
    }

    open override func awakeFromNib() {
        super.awakeFromNib()

        applyCustomizations()
    }

    // MARK: - Custom appearance

    open override var effectiveAppearance: NSAppearance {
        return NSAppearance(named: NSAppearanceNameVibrantDark)!
    }

    fileprivate var titlebarWidgets = Set<NSButton>()

    fileprivate func appearanceForWidgets() -> NSAppearance? {
        return NSAppearance(named: NSAppearanceNameAqua)
    }

    fileprivate func applyAppearanceToWidgets() {
        let appearance = appearanceForWidgets()
        titlebarWidgets.forEach { $0.appearance = appearance }
    }

    fileprivate var _storedTitlebarView: NSVisualEffectView?
    open var titlebarView: NSVisualEffectView? {
        guard _storedTitlebarView == nil else { return _storedTitlebarView }
        guard let containerClass = NSClassFromString("NSTitlebarContainerView") else { return nil }

        guard let containerView = contentView?.superview?.subviews.filter({ $0.isKind(of: containerClass) }).last else { return nil }

        guard let titlebar = containerView.subviews.filter({ $0.isKind(of: NSVisualEffectView.self) }).last as? NSVisualEffectView else { return nil }

        _storedTitlebarView = titlebar

        return _storedTitlebarView
    }

    fileprivate var titleTextField: NSTextField?
    fileprivate var titlebarSeparatorLayer: CALayer?
    fileprivate var titlebarGradientLayer: CAGradientLayer?

    fileprivate var fullscreenObserver: NSObjectProtocol?

    fileprivate func applyCustomizations(_ note: Notification? = nil) {
        titleVisibility = .hidden
        isMovableByWindowBackground = true

        titlebarView?.material = .ultraDark
        titlebarView?.state = .active

        installTitlebarGradientIfNeeded()
        installTitlebarSeparatorIfNeeded()
        installTitleTextFieldIfNeeded()

        installFullscreenObserverIfNeeded()

        applyAppearanceToWidgets()
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
        titleTextField!.font = .titleBarFont(ofSize: 13.0)
        titleTextField!.textColor = NSColor(calibratedWhite: 0.9, alpha: 0.8)
        titleTextField!.alignment = .center
        titleTextField!.translatesAutoresizingMaskIntoConstraints = false
        titleTextField!.lineBreakMode = .byTruncatingMiddle
        titleTextField!.sizeToFit()

        titlebarView!.addSubview(titleTextField!)
        titleTextField!.centerYAnchor.constraint(equalTo: titlebarView!.centerYAnchor).isActive = true
        titleTextField!.centerXAnchor.constraint(equalTo: titlebarView!.centerXAnchor).isActive = true
        titleTextField!.leadingAnchor.constraint(greaterThanOrEqualTo: titlebarView!.leadingAnchor, constant: 67.0).isActive = true
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
        titlebarSeparatorLayer!.backgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.9).cgColor
        titlebarSeparatorLayer!.frame = CGRect(x: 0.0, y: 0.0, width: titlebarView!.bounds.width, height: 1.0)
        titlebarSeparatorLayer!.autoresizingMask = [.layerWidthSizable, .layerMinYMargin]
        titlebarView?.layer?.addSublayer(titlebarSeparatorLayer!)
    }

    fileprivate func installFullscreenObserverIfNeeded() {
        guard fullscreenObserver == nil else { return }

        let nc = NotificationCenter.default

        // the customizations (especially the title text field ones) have to be reapplied when entering and exiting fullscreen
        nc.addObserver(forName: NSNotification.Name.NSWindowDidEnterFullScreen, object: self, queue: nil, using: applyCustomizations)
        nc.addObserver(forName: NSNotification.Name.NSWindowDidExitFullScreen, object: self, queue: nil, using: applyCustomizations)
    }

    open override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)

        applyCustomizations()
    }

    // MARK: - Titlebar management

    public private(set) var titlebarCompanionViews = [NSView]()

    public func addTitlebarCompanion(view: NSView) {
        guard titlebarCompanionViews.index(of: view) == nil else { return }

        titlebarCompanionViews.append(view)
    }

    public func removeTitlebarCompanion(view: NSView) {
        guard let index = titlebarCompanionViews.index(of: view) else { return }

        titlebarCompanionViews.remove(at: index)
    }

    func hideTitlebar(_ animated: Bool = true) {
        setTitlebarOpacity(0.0, animated: animated)
    }

    func showTitlebar(_ animated: Bool = true) {
        setTitlebarOpacity(1.0, animated: animated)
    }

    fileprivate func setTitlebarOpacity(_ opacity: CGFloat, animated: Bool) {
        guard hidesTitlebar else { return }

        // when the window is in full screen, the titlebar view is in another window (the "toolbar window")
        guard titlebarView?.window == self else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = animated ? 0.4 : 0.0
            self.titlebarView?.animator().alphaValue = opacity
            self.titlebarCompanionViews.forEach({ $0.animator().alphaValue = opacity })
        }, completionHandler: nil)
    }

    open override func standardWindowButton(_ b: NSWindowButton) -> NSButton? {
        guard let button = super.standardWindowButton(b) else { return nil }

        titlebarWidgets.insert(button)

        return button
    }

    // MARK: - Content management

    open override var title: String {
        didSet {
            titleTextField?.stringValue = title
        }
    }

    open override var contentView: NSView? {
        set {
            let darkContentView = PUIPlayerWindowContentView(frame: newValue?.frame ?? NSZeroRect)
            if let newContentView = newValue {
                newContentView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
                darkContentView.addSubview(newContentView)
            }
            super.contentView = darkContentView
        }
        get {
            return super.contentView
        }
    }

}

private class PUIPlayerWindowContentView: NSView {

    fileprivate var overlayView: PUIPlayerWindowOverlayView?

    fileprivate func installOverlayView() {
        overlayView = PUIPlayerWindowOverlayView(frame: bounds)
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
        NSColor.black.setFill()
        NSRectFill(dirtyRect)
    }

    fileprivate override func addSubview(_ aView: NSView) {
        super.addSubview(aView)

        if aView != overlayView {
            moveOverlayViewToTop()
        }
    }

}

private class PUIPlayerWindowOverlayView: NSView {

    fileprivate var PUIPlayerWindow: PUIPlayerWindow? {
        return window as? PUIPlayerWindow
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

        mouseIdleTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(mouseIdleTimerAction), userInfo: nil, repeats: false)
    }

    @objc fileprivate func mouseIdleTimerAction(_ sender: Timer) {
        PUIPlayerWindow?.hideTitlebar()
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
        PUIPlayerWindow?.showTitlebar()
    }

    fileprivate override func mouseExited(with theEvent: NSEvent) {
        PUIPlayerWindow?.hideTitlebar()
    }

    fileprivate override func mouseMoved(with theEvent: NSEvent) {
        resetMouseIdleTimer()
        PUIPlayerWindow?.showTitlebar()
    }

    fileprivate override func draw(_ dirtyRect: NSRect) {
        return
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        mouseIdleTimer.invalidate()
        mouseIdleTimer = nil
    }

}
