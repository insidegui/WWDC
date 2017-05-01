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
    func timelineDidReceiveForceTouch(at timestamp: Double)
    func timelineDidHighlightAnnotation(_ annotation: PUITimelineAnnotation?)
    
}
