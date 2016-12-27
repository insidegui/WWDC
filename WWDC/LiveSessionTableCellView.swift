//
//  LiveSessionTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

protocol LiveSessionTableCellViewDelegate {
    func playLiveSession(_ session: LiveSession)
}

class LiveSessionTableCellView: NSTableCellView {

    var delegate: LiveSessionTableCellViewDelegate?
    
    @IBOutlet weak fileprivate var playButton: NSButton!
    @IBOutlet weak fileprivate var timeRemainingView: RoundRectLabel!
    @IBOutlet weak fileprivate var titleTextField: NSTextField!
    
    fileprivate lazy var formatter: DateFormatter = {
        let f = DateFormatter()
        
        f.timeStyle = .short
        
        return f
    }()
    
    var session: LiveSession? {
        didSet {
            updateUI()
        }
    }
    
    fileprivate func updateUI() {
        guard let session = session else { return }
        
        titleTextField.stringValue = session.title
        
        if let endsAt = session.endsAt {
            timeRemainingView.title = "Ends at " + formatter.string(from: endsAt as Date)
            timeRemainingView.isHidden = false
        } else {
            timeRemainingView.isHidden = true
        }
    }
    
    @IBAction func play(_ sender: NSButton) {
        guard let session = session else { return }
        
        delegate?.playLiveSession(session)
    }
    
}
