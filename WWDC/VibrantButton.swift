//
//  VibrantButton.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VibrantButton: NSView {

    var target: Any?
    var action: Selector?

    var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
            sizeToFit()
        }
    }

    var state: NSControl.StateValue = .off {
        didSet {
            if state == .on {
                titleLabel.textColor = .primary
            } else {
                titleLabel.textColor = .primaryText
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius=10

        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 18)
        l.textColor = .primaryText
        l.lineBreakMode = .byTruncatingTail
        l.alignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    private lazy var vfxView: NSVisualEffectView = {
        let v = NSVisualEffectView(frame: .zero)

        v.translatesAutoresizingMaskIntoConstraints = false
        v.blendingMode = .withinWindow
        v.material = .ultraDark
        v.appearance = NSAppearance(named: .vibrantDark)
        v.state = .active

        return v
    }()

    private func buildUI() {
        addSubview(vfxView)
        vfxView.addSubview(titleLabel)

        vfxView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        vfxView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        vfxView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        vfxView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        titleLabel.centerXAnchor.constraint(equalTo: vfxView.centerXAnchor).isActive = true
        titleLabel.centerYAnchor.constraint(equalTo: vfxView.centerYAnchor).isActive = true

        sizeToFit()
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: titleLabel.intrinsicContentSize.width + 74,
                      height: titleLabel.intrinsicContentSize.height + 24)
    }

    func sizeToFit() {
        titleLabel.sizeToFit()
        frame = NSRect(origin: frame.origin, size: intrinsicContentSize)
    }

    override func mouseDown(with event: NSEvent) {
        state = .on
    }

    override func mouseUp(with event: NSEvent) {
        if let target = target, let action = action {
            NSApp.sendAction(action, to: target, from: self)
        }

        state = .off
    }

}
