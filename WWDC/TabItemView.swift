//
//  TabItemView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfUIFoundation
import Combine

extension NSStackView {

    var computedContentSize: CGSize {
        func horizontal() -> CGSize {
            let height = arrangedSubviews.map({ $0.bounds.height }).max() ?? CGFloat(0)
            let width = arrangedSubviews.reduce(CGFloat(0), { $0 + $1.intrinsicContentSize.width + spacing })

            return CGSize(width: width - spacing, height: height)
        }

        switch orientation {
        case .horizontal:
            return horizontal()
        case .vertical:
            let width = arrangedSubviews.map({ $0.bounds.width }).max() ?? CGFloat(0)
            let height = arrangedSubviews.reduce(CGFloat(0), { $0 + $1.intrinsicContentSize.height + spacing })

            return CGSize(width: width, height: height - spacing)
        @unknown default:
            assertionFailure("An unexpected case was discovered on an non-frozen obj-c enum")
            return horizontal()
        }
    }

}

final class TabItemView: NSView {

    @objc var target: Any?
    @objc var action: Selector?

    var controllerIdentifier: String = ""

    var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
            titleLabel.sizeToFit()
            sizeToFit()
        }
    }

    var image: NSImage? {
        didSet {
            if state == .off {
                imageView.image = image
                sizeToFit()
            }
        }
    }

    var activeColor: NSColor { .desaturatedAccentColor }
    var inactiveColor: NSColor { .secondaryLabelColor }

    var state: NSControl.StateValue = .off {
        didSet { needsLayout = true }
    }

    lazy var imageView: NSImageView = {
        let v = NSImageView()

        v.contentTintColor = .secondaryLabelColor
        v.widthAnchor.constraint(equalToConstant: 20).isActive = true
        v.heightAnchor.constraint(equalToConstant: 15).isActive = true

        return v
    }()

    lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")

        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabelColor

        return l
    }()

    lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.imageView, self.titleLabel])

        v.orientation = .horizontal
        v.spacing = 8
        v.alignment = .centerY
        v.distribution = .equalCentering

        return v
    }()

    override var intrinsicContentSize: NSSize {
        get {
            var s = stackView.computedContentSize
            s.width += 29
            return s
        }
        set { }
    }

    private var uiMaskNotificationTokens: [NSObjectProtocol] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

        addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        titleLabel.centerYAnchor.constraint(equalTo: stackView.centerYAnchor, constant: -1).isActive = true

        let showToken = NotificationCenter.default.addObserver(forName: .WWDCWindowWillShowUIMask, object: nil, queue: .main) { [weak self] _ in
            self?.isEnabled = false
        }
        let hideToken = NotificationCenter.default.addObserver(forName: .WWDCWindowWillHideUIMask, object: nil, queue: .main) { [weak self] _ in
            self?.isEnabled = true
        }

        uiMaskNotificationTokens = [showToken, hideToken]
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func sizeToFit() {
        frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: intrinsicContentSize.width, height: intrinsicContentSize.height)
    }

    var isEnabled = true {
        didSet {
            animator().alphaValue = isEnabled ? 1 : 0.3
        }
    }
    
    override var mouseDownCanMoveWindow: Bool { false }

    override func layout() {
        super.layout()

        guard let window else { return }

        let effectiveActiveColor = window.isKeyWindow ? activeColor : inactiveColor
        let color = state == .on ? effectiveActiveColor : isHovered ? inactiveColor.withSystemEffect(.rollover) : inactiveColor
        let effectiveColor = isPressed ? color.withSystemEffect(.pressed) : color

        imageView.contentTintColor = effectiveColor
        titleLabel.textColor = effectiveColor
    }

    private lazy var windowCancellables = Set<AnyCancellable>()

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window else {
            windowCancellables.removeAll()
            return
        }

        Publishers.Merge(
            NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification, object: window),
            NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification, object: window)
        ).sink { [weak self] _ in
            guard let self = self else { return }
            self.needsLayout = true
        }
        .store(in: &windowCancellables)
    }

    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverArea {
            removeTrackingArea(hoverArea)
        }

        let area = NSTrackingArea(rect: bounds, options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    private var isHovered = false {
        didSet { needsLayout = true }
    }

    private var isPressed = false {
        didSet { needsLayout = true }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)

        guard state != .on else { return }

        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        guard state != .on else { return }

        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        guard state != .on else {
            super.mouseDown(with: event)
            return
        }

        isPressed = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard state != .on else {
            super.mouseDragged(with: event)
            return
        }

        guard let superview else { return }
        let p = superview.convert(event.locationInWindow, from: nil)
        let p2 = convert(p, from: superview)

        isHovered = bounds.contains(p2)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)

        guard state != .on else { return }

        isPressed = false

        guard isEnabled, isHovered else { return }

        if let target = target, let action = action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

}

extension NSColor {
    /// A version of the system accent color desaturated to look better in vibrant contexts.
    static var desaturatedAccentColor: NSColor {
        .toolbarTintActive.blended(withFraction: 0.2, of: .white) ?? .toolbarTintActive
    }
}
