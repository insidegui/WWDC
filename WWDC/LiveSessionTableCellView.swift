//
//  LiveSessionTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

protocol LiveSessionTableCellViewDelegate {
    func playLiveSession(session: LiveSession)
}

class LiveSessionTableCellView: NSTableCellView {

    var delegate: LiveSessionTableCellViewDelegate?
    
    @IBOutlet weak private var playButton: NSButton!
    @IBOutlet weak private var timeRemainingView: RoundRectLabel!
    @IBOutlet weak private var titleTextField: NSTextField!
    
    private lazy var formatter: NSDateFormatter = {
        let f = NSDateFormatter()
        
        f.timeStyle = .ShortStyle
        
        return f
    }()
    
    var session: LiveSession? {
        didSet {
            updateUI()
        }
    }
    
    private func updateUI() {
        guard let session = session else { return }
        
        titleTextField.stringValue = session.title
        
        if let endsAt = session.endsAt {
            timeRemainingView.title = "Ends at " + formatter.stringFromDate(endsAt)
            timeRemainingView.hidden = false
        } else {
            timeRemainingView.hidden = true
        }
    }
    
    @IBAction func play(sender: NSButton) {
        guard let session = session else { return }
        
        delegate?.playLiveSession(session)
    }
    
}
