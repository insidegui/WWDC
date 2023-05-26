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

    fileprivate var _storedTitlebarContainerView: NSView?
    public var titlebarContainerView: NSView? {
        guard _storedTitlebarContainerView == nil else { return _storedTitlebarContainerView }
        guard let containerClass = NSClassFromString("NSTitlebarContainerView") else { return nil }

        guard let containerView = contentView?.superview?.subviews.reversed().first(where: { $0.isKind(of: containerClass) }) else { return nil }

        _storedTitlebarContainerView = containerView

        return _storedTitlebarContainerView
    }

    private lazy var titlebarLook: NSView = {
        let v = NSVisualEffectView()

        v.wantsLayer = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.material = .headerView
        v.appearance = NSAppearance(named: .darkAqua)
        v.blendingMode = .withinWindow
        v.state = .followsWindowActiveState

        let divider = NSView.divider
        v.addSubview(divider)

        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: v.bottomAnchor)
        ])

        return v
    }()

    fileprivate func applyCustomizations(_ note: Notification? = nil) {
        backgroundColor = .darkWindowBackground

        titleVisibility = .hidden
        isMovableByWindowBackground = true
        tabbingMode = .disallowed
        titleVisibility = .hidden
        toolbar = NSToolbar(identifier: "DummyToolbar")
        titlebarAppearsTransparent = true
        toolbarStyle = .unified

        guard let titlebarContainerView else { return }

        titlebarContainerView.addSubview(titlebarLook, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            titlebarLook.leadingAnchor.constraint(equalTo: titlebarContainerView.leadingAnchor),
            titlebarLook.trailingAnchor.constraint(equalTo: titlebarContainerView.trailingAnchor),
            titlebarLook.topAnchor.constraint(equalTo: titlebarContainerView.topAnchor),
            titlebarLook.bottomAnchor.constraint(equalTo: titlebarContainerView.bottomAnchor)
        ])
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

private final class WWDCUIMaskView: NSView {

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

extension NSView {
    static var divider: NSBox {
        let v = NSBox()

        v.wantsLayer = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.boxType = .custom
        v.fillColor = NSColor.black.withAlphaComponent(0.5)
        v.borderWidth = 0
        v.appearance = NSAppearance(named: .darkAqua)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true

        return v
    }
}
