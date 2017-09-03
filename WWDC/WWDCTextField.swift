//
//  WWDCTextField.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTextField: NSTextField {

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        NotificationCenter.default.removeObserver(self, name: .NSViewFrameDidChange, object: superview)

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
        NotificationCenter.default.addObserver(self, selector: #selector(superviewFrameDidChange), name: .NSViewFrameDidChange, object: superview)
    }

    @objc private func superviewFrameDidChange() {
        invalidateIntrinsicContentSize()
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)

        invalidateIntrinsicContentSize()
    }

}
