//
//  WWDCWindow.swift
//  WWDC
//
//  Created by Guilherme Rambo on 15/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCWindow: NSWindow {

    // MARK: - Initialization
    
    public override init(contentRect: NSRect, styleMask style: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        
        applyCustomizations()
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        applyCustomizations()
    }
    
    // MARK: - Custom appearance
    
    fileprivate var _storedTitlebarView: NSVisualEffectView?
    open var titlebarView: NSVisualEffectView? {
        guard _storedTitlebarView == nil else { return _storedTitlebarView }
        guard let containerClass = NSClassFromString("NSTitlebarContainerView") else { return nil }
        
        guard let containerView = contentView?.superview?.subviews.filter({ $0.isKind(of: containerClass) }).last else { return nil }
        
        guard let titlebar = containerView.subviews.filter({ $0.isKind(of: NSVisualEffectView.self) }).last as? NSVisualEffectView else { return nil }
        
        _storedTitlebarView = titlebar
        
        return _storedTitlebarView
    }
    
    fileprivate func applyCustomizations(_ note: Notification? = nil) {
        backgroundColor = .darkWindowBackground
        
        titleVisibility = .hidden
        isMovableByWindowBackground = true
		tabbingMode = NSWindowTabbingMode.disallowed
        
        titlebarView?.material = .ultraDark
        titlebarView?.state = .inactive
        titlebarView?.layer?.backgroundColor = NSColor.darkTitlebarBackground.cgColor
    }
    
}
