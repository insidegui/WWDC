//
//  DownloadsManagementTableView.swift
//  WWDC
//
//  Created by Allen Humphreys on 10/22/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class DownloadsManagementTableView: WWDCTableView {

    override func mouseDown(with event: NSEvent) {
        superview?.mouseDown(with: event)
    }
}
