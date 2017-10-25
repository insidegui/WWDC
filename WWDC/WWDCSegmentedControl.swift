//
//  WWDCSegmentedControl.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class WWDCSegmentedControl: NSSegmentedControl {

    var padding: NSEdgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12) {
        didSet {
            resizeSegments()
        }
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: superview)
        superview?.postsFrameChangedNotifications = false
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        setupForSuperview()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        setupForSuperview()
    }

    private func setupForSuperview() {
        guard let superview = superview else { return }

        superview.postsFrameChangedNotifications = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(resizeSegments),
                                               name: NSView.frameDidChangeNotification,
                                               object: superview)

        resizeSegments()
    }

    private let nudge: CGFloat = 2.0

    @objc private func resizeSegments() {
        guard let superview = superview else { return }

        let containmentWidth = superview.bounds.width - padding.left - padding.right - nudge

        let segmentWidth = floor(containmentWidth / CGFloat(segmentCount))

        (0..<segmentCount).forEach({ setWidth(segmentWidth, forSegment: $0) })
    }

}
