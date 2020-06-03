//
//  TabItemView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

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

    var alternateImage: NSImage? {
        didSet {
            if state == .on {
                imageView.image = alternateImage
                sizeToFit()
            }
        }
    }

    var state: NSControl.StateValue = .off {
        didSet {
            if state == .on {
                imageView.tintColor = .toolbarTintActive
                imageView.image = alternateImage ?? image
                titleLabel.textColor = .toolbarTintActive
                titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
            } else {
                imageView.tintColor = .toolbarTint
                imageView.image = image
                titleLabel.textColor = .toolbarTint
                titleLabel.font = .systemFont(ofSize: 14)
            }
        }
    }

    lazy var imageView: MaskImageView = {
        let v = MaskImageView()

        v.tintColor = .toolbarTint
        v.widthAnchor.constraint(equalToConstant: 20).isActive = true
        v.heightAnchor.constraint(equalToConstant: 15).isActive = true

        return v
    }()

    lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")

        l.font = .systemFont(ofSize: 14)
        l.textColor = .toolbarTint
        l.cell?.backgroundStyle = .dark

        return l
    }()

    lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.imageView, self.titleLabel])

        v.orientation = .horizontal
        v.spacing = 10
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
        // swiftlint:disable:next unused_setter_value
        set {

        }
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

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }

        if let target = target, let action = action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    var isEnabled = true {
        didSet {
            animator().alphaValue = isEnabled ? 1 : 0.3
        }
    }

}
