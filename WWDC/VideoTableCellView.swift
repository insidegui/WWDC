//
//  VideoTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideoTableCellView: NSTableCellView {
    
    @IBOutlet weak var titleField: NSTextField!
    @IBOutlet weak var detailsField: NSTextField!
    @IBOutlet weak var progressView: SessionProgressView!
    @IBOutlet weak var trackField: NSTextField!
    @IBOutlet weak var platformsField: NSTextField!
    
}
