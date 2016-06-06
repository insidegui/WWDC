//
//  ScheduledSessionTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

class ScheduledSessionTableCellView: NSTableCellView {

    var session: Session! {
        willSet {
            KVOController.unobserve(session)
        }
        didSet {
            updateUI()
        }
    }
    
    @IBOutlet weak private var titleField: NSTextField!
    @IBOutlet weak private var detailsField: NSTextField!
    @IBOutlet weak var favoriteIndicator: NSTextField!
    @IBOutlet weak var trackDecorationView: NSView! {
        didSet {
            trackDecorationView.wantsLayer = true
            trackDecorationView.layer = CALayer()
        }
    }
    
    private lazy var dateFormatter: NSDateFormatter = {
        let f = NSDateFormatter()
        
        f.locale = NSLocale(localeIdentifier: "en")
        f.dateFormat = "E"
        
        return f
    }()
    
    private lazy var timeFormatter: NSDateFormatter = {
        let f = NSDateFormatter()
        
        f.dateFormat = "HH:mm"
        
        return f
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
        KVOController.unobserve(session)
    }
    
    private func updateUI() {
        KVOController.observe(session, keyPath: "favorite", options: .New, action: #selector(updateSessionFlags))
        
        titleField.stringValue = session.title
        
        if let schedule = session.schedule {
            if let track = schedule.track { updateTrackDecorationWithTrack(track) }
            
            let day = dateFormatter.stringFromDate(schedule.startsAt)
            let startTime = timeFormatter.stringFromDate(schedule.startsAt)
            let endTime = timeFormatter.stringFromDate(schedule.endsAt)
            
            detailsField.stringValue = "\(day) \(startTime) - \(endTime) − \(schedule.room)"
        } else {
            detailsField.stringValue = "\(session.year) - Session \(session.id) - \(session.track)"
        }
        
        updateSessionFlags()
    }
    
    func updateTrackDecorationWithTrack(track: Track) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.0)
        trackDecorationView.layer?.backgroundColor = NSColor(hexString: track.color)?.CGColor
        CATransaction.commit()
    }
    
    func updateSessionFlags() {
        favoriteIndicator.hidden = !session.favorite
    }
    
}
