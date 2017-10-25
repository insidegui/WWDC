//
//  PUITimelineDelegate.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

public protocol PUITimelineDelegate: class {

    func viewControllerForTimelineAnnotation(_ annotation: PUITimelineAnnotation) -> NSViewController?
    func timelineDidHighlightAnnotation(_ annotation: PUITimelineAnnotation?)
    func timelineDidSelectAnnotation(_ annotation: PUITimelineAnnotation?)

    func timelineCanDeleteAnnotation(_ annotation: PUITimelineAnnotation) -> Bool
    func timelineCanMoveAnnotation(_ annotation: PUITimelineAnnotation) -> Bool

    func timelineDidMoveAnnotation(_ annotation: PUITimelineAnnotation, to timestamp: Double)
    func timelineDidDeleteAnnotation(_ annotation: PUITimelineAnnotation)

}
