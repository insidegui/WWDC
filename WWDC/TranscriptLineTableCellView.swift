//
//  TranscriptLineTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class TranscriptLineTableCellView: NSTableCellView {

    @IBOutlet weak fileprivate var playButton: NSButton?
    @IBOutlet weak fileprivate var summaryLabel: NSTextField!
    
    var selected = false {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    var foregroundColor: NSColor?
    var font: NSFont?
    
    var playCallback: ((_ startTime: Double) -> Void)?
    
    var line: TranscriptLine? {
        didSet {
            updateUI()
        }
    }
    
    @IBAction func play(_ sender: NSButton) {
        guard let line = self.line else { return }
        playCallback?(line.timecode)
    }
    
    fileprivate func updateUI() {
        guard let line = self.line else { return }
        summaryLabel.stringValue = line.text
        
        summaryLabel.textColor = foregroundColor
        summaryLabel.font = font
        summaryLabel.cell?.backgroundStyle = NSBackgroundStyle.light
    }
    
    override func setNeedsDisplay(_ invalidRect: NSRect) {
        super.setNeedsDisplay(invalidRect)

        if selected {
            summaryLabel.textColor = NSColor.black
        } else {
            summaryLabel.textColor = foregroundColor
        }
    }
    
}
