//
//  TranscriptLineTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class TranscriptLineTableCellView: NSTableCellView {

    @IBOutlet weak private var playButton: NSButton?
    @IBOutlet weak private var summaryLabel: NSTextField!
    
    var selected = false {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    var foregroundColor: NSColor?
    var font: NSFont?
    
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
        
        summaryLabel.textColor = foregroundColor
        summaryLabel.font = font
        summaryLabel.cell?.backgroundStyle = NSBackgroundStyle.Light
    }
    
    override func setNeedsDisplayInRect(invalidRect: NSRect) {
        super.setNeedsDisplayInRect(invalidRect)

        if selected {
            summaryLabel.textColor = NSColor.blackColor()
        } else {
            summaryLabel.textColor = foregroundColor
        }
    }
    
}
