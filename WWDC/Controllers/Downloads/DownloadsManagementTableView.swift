//
//  DownloadsManagementTableView.swift
//  WWDC
//
//  Created by Allen Humphreys on 10/22/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class DownloadsManagementTableView: WWDCTableView {

    // This allows the detached window to be movable
    // by grabbing anywhere in the table
    override var mouseDownCanMoveWindow: Bool {
        return true
    }

    // This allows the popover to be detached by grabbing
    // anywhere in the table
    override func mouseDown(with event: NSEvent) {
        superview?.mouseDown(with: event)
    }
}
