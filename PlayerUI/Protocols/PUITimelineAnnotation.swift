//
//  PUITimelineAnnotation.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 01/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

public protocol PUITimelineAnnotation {
    var identifier: String { get }
    var timestamp: Double { get }
    var isValid: Bool { get }
    var isEmpty: Bool { get }
}
