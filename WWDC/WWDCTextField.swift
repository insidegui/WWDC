//
//  WWDCTextField.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTextField: NSTextField {

    private var _allowsVibrancy: Bool = false
    override var allowsVibrancy: Bool {
        get {
            return _allowsVibrancy
        }
        set {
            assert(window == nil, "You can't change this property when it's in a view hiearchy")
            _allowsVibrancy = newValue
        }
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: superview)

        super.viewWillMove(toSuperview: newSuperview)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        viewDidMoveToSuperview()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        fixApplesTextFieldSizingBehavior()
    }

    override var stringValue: String {
        didSet {
            invalidateIntrinsicContentSize()
            superview?.needsUpdateConstraints = true
        }
    }

    public override func prepareForReuse() {
        invalidateIntrinsicContentSize()
    }

    func fixApplesTextFieldSizingBehavior() {
        superview?.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(superviewFrameDidChange), name: NSView.frameDidChangeNotification, object: superview)
    }

    @objc private func superviewFrameDidChange() {
        invalidateIntrinsicContentSize()
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)

        invalidateIntrinsicContentSize()
    }

}
