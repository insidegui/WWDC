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

    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
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

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {

        // Prevent NSSearchField in the filters controller from becoming the first responder automatically
        // search_field_responder_tag
        if let event = currentEvent,
            let searchField = responder as? NSSearchField {

            let pointInView = searchField.convert(event.locationInWindow, from: nil)
            if !searchField.mouse(pointInView, in: searchField.bounds) {
                return false
            }
        } else if currentEvent == nil {
            // Prevents automatic state restoration
            return false
        }

        return super.makeFirstResponder(responder)
    }
}
