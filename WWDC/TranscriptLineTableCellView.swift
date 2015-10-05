//
//  TranscriptLineTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class TranscriptLineTableCellView: NSTableCellView {

    @IBOutlet weak private var playButton: NSButton!
    @IBOutlet weak private var summaryLabel: NSTextField!
    
    var playCallback: ((startTime: Double) -> Void)?
    
    var line: TranscriptLine? {
        didSet {
            updateUI()
        }
    }
    
    @IBAction func play(sender: NSButton) {
        guard let line = self.line else { return }
        playCallback?(startTime: line.timecode)
    }
    
    private func updateUI() {
        guard let line = self.line else { return }
        summaryLabel.stringValue = line.text
    }
    
}
